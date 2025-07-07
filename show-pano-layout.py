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

Launch with -h to print CLI help
'''

def parse_image_line(line):
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

    if part.startswith('n"') and part.endswith('"'):
      # todo: handle spaces in names 
      ret['n'] = part[2:-1]

  print(f'IMAGE: {ret}')
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

  print(f'PANO:  {ret}')
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
        ret['images'].append(parse_image_line(line))
      if line.startswith('p'):
        ret['pano'] = parse_pano_line(line)
    
  return ret

def main():

  parser = argparse.ArgumentParser(
    description="Show panorama layout on a PNG image."
  )

  parser.add_argument('-i', '--input',  type=str, required=True, help='Input PTO file (required).')
  parser.add_argument('-o', '--output', type=str, required=True, help='Output PNG file (required).')

  args = parser.parse_args()

  print(f'Load PTO from {args.input}')
  pto = load_pto(args.input)


  w, h = 1920, 1080

  # creating new Image object
  img = Image.new('RGB', (w, h), 'white')

  # create line image
  draw = ImageDraw.Draw(img)  


  cw, ch = 1800, 900
  cx1 = (w - cw) / 2
  cx2 = cx1 + cw
  cx0 = (cx1 + cx2) / 2
  cy1 = h - ch - cx1
  cy2 = cy1 + ch
  cy0 = (cy1 + cy2) / 2

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
    x = cx0 + cw * i / 360
    lw = 3 if i % 180 == 0 else 1
    draw.line([x, cy1, x, cy2], fill = grid_color, width = lw)

    if i % 30 == 0:
      t = str(i)
      # see https://pillow.readthedocs.io/en/stable/handbook/text-anchors.html
      draw.text((x, cy2 + 15), t, fill=grid_label_color, font=grid_label_font, anchor='mt')
  
  # pitch
  for i in range(-90, 91, 10):
    y = cy0 - ch * i / 180
    lw = 3 if i % 90 == 0 else 1
    draw.line([cx1, y, cx2, y], fill = grid_color, width = lw)

    if i % 30 == 0:
      t = str(i)
      draw.text((cx1 - 10, y), t, fill=grid_label_color, font=grid_label_font, anchor='rm')

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

  # Image labels
  for i, ii in enumerate(pto['images']):
    x = cx0 + cw * ii['y'] / 360
    y = cy0 - ch * ii['p'] / 180
    draw.text((x, y - 15), f'#{i}', fill=img_label_color, font=img_label1_font, anchor='mb')
    draw.text((x, y + 15), f'{ii['n']}', fill=img_label_color, font=img_label2_font, anchor='mt')

  # Image rects
  for i, ii in enumerate(pto['images']):
    x = cx0 + cw * ii['y'] / 360
    y = cy0 - ch * ii['p'] / 180
    ax = 40 * math.sin(ii['r'] * math.pi / 180)
    ay = -40 * math.cos(ii['r'] * math.pi / 180)
    draw.rectangle([ x - 10, y - 10, x + 10, y + 10], fill = None, outline = 'black', width = 2)
    draw.line([x, y, x + ax, y + ay], fill='black', width=1)

  print(f'Write chart to {args.output}')
  img.save(args.output)

  print('Done.')

if __name__ == '__main__':
  main()
