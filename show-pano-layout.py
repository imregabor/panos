#!/usr/bin/env python3

import math
# See https://pillow.readthedocs.io/en/latest/installation/basic-installation.html
from PIL import Image, ImageDraw, ImageFont
import argparse
import os

'''
Show pano layout on a rendered PNG image
 - FOV, crop, pixel size info
 - Image positions, rotations

Only a very limited feature set is supported:
 - Output panorama projection is assumed to be equirectangular
 - Lenses are assumed to be rectilinear
 - Inefficient, partial lens correction implementation
 - no image center shift, no shearing correction

Launch with -h to print CLI help
See test/run-layout-test-renders.sh to exercise on synthetic panoramas
'''

def parse_image_line(line, prior_images):
  # approxiate format, consider handling spaces in names
  parts = line.split()

  ret = {}
  for part in parts:
    if part.startswith('w'): 
      ret['w'] = int(part[1:])

    if part.startswith('h'): 
      ret['h'] = int(part[1:])
    
    if part.startswith('r'): 
      ret['r'] = float(part[1:])
    
    if part.startswith('p'): 
      ret['p'] = float(part[1:])
    
    if part.startswith('y'): 
      ret['y'] = float(part[1:])

    if part.startswith('v='):
      ret['v'] = prior_images[int(part[2:])]['v']
    elif part.startswith('v'):
      ret['v'] = float(part[1:])

    if part.startswith('a='):
      ret['a'] = prior_images[int(part[2:])]['a']
    elif part.startswith('a'):
      ret['a'] = float(part[1:])

    if part.startswith('b='):
      ret['b'] = prior_images[int(part[2:])]['b']
    elif part.startswith('b'):
      ret['b'] = float(part[1:])

    if part.startswith('c='):
      ret['c'] = prior_images[int(part[2:])]['c']
    elif part.startswith('c'):
      ret['c'] = float(part[1:])

    if part.startswith('n"') and part.endswith('"'):
      # todo: handle spaces in names 
      ret['n'] = part[2:-1]

  ret['v_vertical'] = ret['v'] * ret['h'] / ret['w']

  print(f'  image line: {ret}')
  return ret

def parse_pano_line(line):
  # n (nona opts?) part is totally mishandled
  parts = line.split()
  ret = {}
  for part in parts:
    if part.startswith('S'):
      v = part[1:].split(',')
      if len(v) != 4:
        raise Exception(f'Expected 4 valuesm got {len(v)} in S part in p line "{line}"')
      ret['crop_x1'] = int(v[0])
      ret['crop_x2'] = int(v[1])
      ret['crop_y1'] = int(v[2])
      ret['crop_y2'] = int(v[3])

    if part.startswith('w'): 
     ret['w'] = int(part[1:])

    if part.startswith('h'): 
     ret['h'] = int(part[1:])

    if part.startswith('v'): 
     ret['v'] = float(part[1:])

  # maybe incorrect?
  ret['v_vertical'] = ret['v'] * ret['h'] / ret['w']

  if not 'crop_x1' in ret:
    ret['crop_x1'] = 0
    ret['crop_x2'] = ret['w']
    ret['crop_y1'] = 0
    ret['crop_y2'] = ret['h']

  print(f'  pano line:  {ret}')
  return ret

def load_pto(path):
  ret = {
    'images' : []
  }
  with open(path, 'r') as f:
    for line in f:
      line = line.strip()
      if not line:
        continue
      if line.startswith('#'):
        continue
      if line.startswith('i'):
        ret['images'].append(parse_image_line(line, ret['images']))
      if line.startswith('p'):
        ret['pano'] = parse_pano_line(line)
    
  return ret


def append_line_segment(points, n, x1, y1, x2, y2):
  '''
  Append n points along line segment. End 1 will be included, end 2 will be excluded.
  '''

  for i in range(n):
    points.append((x1 + i * (x2 - x1) / n, y1 + i * (y2 - y1) / n))


def gen_rect(points, w, h):
  '''
  Clockwise zero centered rectangle perimeter
  '''
  ret = []
  append_line_segment(ret, points, -w / 2, -h / 2,  w / 2, -h / 2)
  append_line_segment(ret, points,  w / 2, -h / 2,  w / 2,  h / 2)
  append_line_segment(ret, points,  w / 2,  h / 2, -w / 2,  h / 2)
  append_line_segment(ret, points, -w / 2,  h / 2, -w / 2, -h / 2)
  return ret

def image_xy_to_equirectangular_yaw_pitch(points, v, w, h):
  '''
  Transform image pixel coordinates to equirectangular projected coordinates (angles)
  '''

  d = w / (2 * math.tan(math.pi * v / 360))

  ret = []
  for (x, y) in points:
    tan_pitch = y / math.sqrt( d * d + x * x)
    tan_yaw   = x / d
    ret.append((180 * math.atan(tan_yaw) / math.pi, 180 * math.atan(tan_pitch) / math.pi))

  return ret

def add_yaw_pitch(points, yaw, pitch):
  '''
  Rotate spherical coordinates.
    - Two (yaw, pitch) rotations are applied to spherical (y, p) coordinates
      - rotate around the yaw (vertical cartesian, used "y" here) is the first step
      - yaw rotation rotates the cartesian "x" (and "z") axes
      - pitch rotation is done around the (yaw rotated)"z" axis
  '''

  # yaw, pitch angles of rotation
  yaw_rad = yaw * math.pi / 180
  pitch_rad = pitch * math.pi / 180

  sin_yaw = math.sin(yaw_rad)
  cos_yaw = math.cos(yaw_rad)
  sin_pitch = math.sin(pitch_rad)
  cos_pitch = math.cos(pitch_rad)

  ret = []

  for (y1, p1) in points:
    # [1] current point denoted by (y1,p1) spherical coordinates (which needs further rotation)
    y1_rad = y1 * math.pi / 180
    p1_rad = p1 * math.pi / 180

    sin_y1 = math.sin(y1_rad)
    cos_y1 = math.cos(y1_rad)
    sin_p1 = math.sin(p1_rad)
    cos_p1 = math.cos(p1_rad)

    # cartesian coordinates or [1] before yaw/pitch further rotation
    cx1 = cos_y1 * cos_p1
    cy1 = sin_p1
    cz1 = sin_y1 * cos_p1

    # [2] further rotated cartesian coordinates of [1] in the yawed cartesian coordinate system (yx points to y=0; yy points upward, yz is the axis of pitch)
    cx2 = cx1 * cos_pitch - cy1 * sin_pitch
    cy2 = cx1 * sin_pitch + cy1 * cos_pitch
    cz2 = cz1

    # [3] pitch and yaw rotated cartesian coordinates in the original coordinate system
    cx3 = cx2 * cos_yaw - cz2 * sin_yaw
    cy3 = cy2
    cz3 = cx2 * sin_yaw + cz2 * cos_yaw

    # calculate spherical coordinates of rotated point
    # note that spherical coordinates to cartesian transformation is
    #   cartesian_x = cos(yaw)   * cos(pitch)
    #   cartesian_y = sin(pitch)
    #   cartesian_z = sin(yaw)   * cos(pitch)

    # values outside -1.0 .. 1.0 range (due to floating point ops) will fail arc sin
    cy3 = max(-1, cy3)
    cy3 = min(1, cy3)

    p3_rad = math.asin(cy3)
    cos_p3 = math.cos(p3_rad)


    cos_y3 = cx3 / cos_p3

    if cos_p3 == 0:
      # zenith or nadir
      y3_rad = 0
    else:
      sin_y3 = cz3 / cos_p3
      sin_y3 = max(-1, sin_y3)
      sin_y3 = min(1, sin_y3)
      y3_rad = math.asin(sin_y3)

      # arc sin will be in the -90 deg .. +90 deg range
      # use the cos value to decide the quadrant

      if cos_y3 < 0:
        # yaw_3 is outside the -90 deg .. 90 deg range
        if sin_y3 > 0:
          y3_rad = math.pi - y3_rad
        else:
          y3_rad = - math.pi - y3_rad

    ret.append((180 * y3_rad / math.pi, 180 * p3_rad / math.pi))

  return ret

def correct_lens_distortion(points, unitd, maxd, a, b, c):
  '''
  See https://hugin.sourceforge.io/docs/manual/Lens_correction_model.html
  And https://wiki.panotools.org/index.php?title=Lens_distortion&oldid=9434
  '''

  d = 1 - (a + b + c)

  img_to_corrected = [0]
  i = 0
  img_r = 0
  corr_r = 0
  while img_r <= 1.1 * maxd and corr_r < 3:
    img_r = corr_r * (a * corr_r * corr_r * corr_r  + b * corr_r * corr_r + c * corr_r + d)
    i_next = round(img_r * 1000)
    while i < i_next:
      img_to_corrected.append(corr_r)
      i = i + 1
    corr_r = corr_r + 0.001

  ret = []

  for (x, y) in points:

    img_r = math.sqrt(x * x + y * y) / unitd
    ii = round(img_r * 1000)
    if ii >= len(img_to_corrected):
      ii = len(img_to_corrected) - 1
    corr_r = img_to_corrected[ii]
    ratio = corr_r / img_r

    ret.append((x * ratio, y * ratio))

  return ret


def rotate_image_xy(points, ccw):
  # since no center shift is supported roll is around the origin
  # pixel space can be used since radial distance (used by subsequent lens correction) is not changed
  a = ccw * math.pi / 180
  xx, xy, yx, yy = math.cos(a), -math.sin(a), math.sin(a), math.cos(a)
  return [ (xx * x + yx * y, xy * x + yy * y) for (x, y) in points ]

def translate(dx, dy, points):
  return [ (dx + x, dy + y) for (x, y) in points ]

def main():
  parser = argparse.ArgumentParser(
    description="Show (or output as PNG) a panorama layout."
  )

  parser.add_argument('-i', '--input',  type=str, required=True, help='Input PTO file (required).')
  parser.add_argument('-o', '--output', type=str, help='Output PNG file instead of display.')
  parser.add_argument('--image-outline-color', type=str, default='#ccc', help='Image outline color (default: "#ccc")')
  parser.add_argument('--image-outline-width', type=int, default=1, help='Image outline line width (default: 1)')

  args = parser.parse_args()

  print()
  print()
  print(f'Load PTO from {args.input}')
  pto = load_pto(args.input)
  print()
  print()
  print('Draw chart')

  w, h = 1920, 1080

  img = Image.new('RGB', (w, h), 'white')
  draw = ImageDraw.Draw(img)

  # Pano chart area width, height in pixels
  cw, ch = 1800, 900

  # Left / right / middle point
  cx1 = (w - cw) / 2
  cx2 = cx1 + cw
  cx0 = (cx1 + cx2) / 2

  # top / bottom / middle point
  cy1 = h - ch - cx1
  cy2 = cy1 + ch
  cy0 = (cy1 + cy2) / 2

  def y2x(yaw, wrap=True):
    if wrap:
      while yaw > 180:
        yaw = yaw - 360
      while yaw < -180:
        yaw = yaw + 360
    return cx0 + cw * yaw / 360

  def p2y(pitch, wrap=True):
    if wrap:
      while pitch > 90:
        pitch = pitch - 180
      while pitch < -90:
        pitch = pitch + 180
    return cy0 - ch * pitch / 180

  def yp2xy(yaw, pitch, wrap=True):
    return y2x(yaw, wrap=wrap), p2y(pitch, wrap=wrap)

  def map_yp2xy(points):
    return [ yp2xy(y, p, wrap=True) for (y,p) in points ]

  grid_color = '#eee'

  # see https://stackoverflow.com/questions/918154/relative-paths-in-python
  # Font retrieved from https://fonts.google.com/specimen/Roboto+Condensed/license
  # licensed under the SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007 (https://openfontlicense.org/open-font-license-official-text/).
  dirname = os.path.dirname(__file__)
  roboto_condensed_regular_ttf = os.path.join(dirname, 'RobotoCondensed-Regular.ttf')

  chart_label1_font = ImageFont.truetype(roboto_condensed_regular_ttf, 35)
  chart_label2_font = ImageFont.truetype(roboto_condensed_regular_ttf, 25)
  chart_label1_font_height = 35
  chart_label_color = '#bbb'

  grid_label_font = ImageFont.truetype(roboto_condensed_regular_ttf, 25)
  grid_label_color = '#bbb'
  img_label1_font = ImageFont.truetype(roboto_condensed_regular_ttf, 20)
  img_label2_font = ImageFont.truetype(roboto_condensed_regular_ttf, 12)
  img_label_color = '#666'

  # Chart label
  draw.text((20, 20), 
    os.path.abspath(args.input), 
    fill=chart_label_color, font=chart_label1_font, anchor='lt')
  pano_pixels = (pto['pano']['crop_x2'] - pto['pano']['crop_x1']) * (pto['pano']['crop_y2'] - pto['pano']['crop_y1'])
  cropped_size = f'{pto['pano']['w']}px x {pto['pano']['h']}px ({round(pano_pixels / 1000000)} Mpx)'
  images_pixels = sum([i['w'] * i['h'] for i in pto['images']])
  pano_fov = f'{round(pto['pano']['v'])}° x {round(pto['pano']['v_vertical'])}°'
  draw.text((20, 20 + chart_label1_font_height), 
    f'{pano_fov}, {cropped_size}, {len(pto['images'])} images (of {round(images_pixels / 1000000)} Mpx)',
    fill=chart_label_color, font=chart_label2_font, anchor='lt')

  # Degree grid with labels
  # yaw
  for i in range(-180, 181, 10):
    x = y2x(i)
    lw = 3 if i % 180 == 0 else 1
    draw.line([x, cy1, x, cy2], fill = grid_color, width = lw)

    if i % 30 == 0:
      t = str(i)
      # see https://pillow.readthedocs.io/en/stable/handbook/text-anchors.html
      draw.text((x, cy2 + 15), t, fill=grid_label_color, font=grid_label_font, anchor='mt')
  
  # pitch
  for i in range(-90, 91, 10):
    y = p2y(i)
    lw = 3 if i % 90 == 0 else 1
    draw.line([cx1, y, cx2, y], fill = grid_color, width = lw)

    if i % 30 == 0:
      t = str(i)
      draw.text((cx1 - 10, y), t, fill=grid_label_color, font=grid_label_font, anchor='rm')

  # Individual image outlines
  for i, ii in enumerate(pto['images']):
    # generate image perimeter in pixel space, origo centered
    imgr = gen_rect(50, ii['w'], ii['h'])

    # radial pixel distance is normalized for lens correction polinomial using the shortest size
    # see https://wiki.panotools.org/Lens_correction_model
    # "... the largest circle that completely fits into an image is said to have radius=1.0 ..."
    radial_unit_distance = min(ii['w'], ii['h']) / 2

    # maximal radial pixel distance after normalizaton
    # this is the normalized distance of a corner
    max_normalized_radial_distance = math.sqrt(ii['w'] * ii['w'] + ii['h'] * ii['h'] ) / (2 * radial_unit_distance)

    imgr = correct_lens_distortion(imgr, radial_unit_distance, max_normalized_radial_distance, ii['a'], ii['b'], ii['c'])
    imgr = rotate_image_xy(imgr, ii['r'])
    imgr = image_xy_to_equirectangular_yaw_pitch(imgr, ii['v'], ii['w'], ii['h'])
    imgr = add_yaw_pitch(imgr, ii['y'], ii['p'])
    imgr = map_yp2xy(imgr)

    for i1 in range(len(imgr)):
      p1 = imgr[i1]
      p2 = imgr[(i1 + 1) % len(imgr)]

      x1, _ = p1
      x2, _ = p2
      if abs(x1 - x2) < 500:
        # dont draw wrap around segments
        draw.line([p1, p2], fill=args.image_outline_color, width=args.image_outline_width)

  # pano bounds
  view_horizontal_half = cw * pto['pano']['v'] / 720
  view_vertical_half = ch * pto['pano']['v_vertical'] /360
  draw.rectangle(
    [cx0 - view_horizontal_half, cy0 - view_vertical_half, cx0 + view_horizontal_half, cy0 + view_vertical_half],
    fill = None, outline = '#888', width = 1)

  crop_x1 = cx0 - view_horizontal_half + 2 * view_horizontal_half * pto['pano']['crop_x1'] / pto['pano']['w']
  crop_x2 = cx0 - view_horizontal_half + 2 * view_horizontal_half * pto['pano']['crop_x2'] / pto['pano']['w']
  crop_y1 = cy0 - view_vertical_half + 2 * view_vertical_half * pto['pano']['crop_y1'] / pto['pano']['h']
  crop_y2 = cy0 - view_vertical_half + 2 * view_vertical_half * pto['pano']['crop_y2'] / pto['pano']['h']

  draw.rectangle(
    [crop_x1, crop_y1, crop_x2, crop_y2],
    fill = None, outline = '#888', width = 3)
  draw.text((crop_x1 + 10, crop_y1 + 10), f'Crop area - {cropped_size}', fill='#888', font=img_label1_font, anchor='lt')
  draw.text((cx0 - view_horizontal_half, cy0 - view_vertical_half - 10), f'Uncropped FOV {pano_fov}', fill='#888', font=img_label1_font, anchor='lb')

  # Image labels, outlines
  for i, ii in enumerate(pto['images']):
    x,y = yp2xy(ii['y'], ii['p'])

    draw.text((x, y - 15), f'#{i}', fill=img_label_color, font=img_label1_font, anchor='mb')
    draw.text((x, y + 15), f'{ii['n']}', fill=img_label_color, font=img_label2_font, anchor='mt')


  # Image center and rotation angle markers
  for i, ii in enumerate(pto['images']):
    x,y = yp2xy(ii['y'], ii['p'])

    ax = 40 * math.sin(ii['r'] * math.pi / 180)
    ay = -40 * math.cos(ii['r'] * math.pi / 180)
    draw.rectangle([ x - 5, y - 5, x + 5, y + 5], fill = None, outline = 'black', width = 2)
    draw.line([x, y, x + ax, y + ay], fill='black', width=1)

  if args.output:
    print(f'Write chart to {args.output}')
    img.save(args.output)
  else:
    print('Show layout')
    img.show();


  print('Done.')
  print()
  print()
  print()

if __name__ == '__main__':
  main()
