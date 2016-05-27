Panos - Simple panorama and video preparing scripts
===================================================

Scripts to prepare panorama pictures with Hugin, associated tools and ImageMagick. Also some video transcoding using
ffmpeg. **This scripts are under development, review well before use.**


Requirements
------------

  -  Linux or Windows + [Cygwin](https://www.cygwin.com)
  -  [Hugin](http://hugin.sourceforge.net/) installed; binaries available in the Path
  -  [ImageMagick](http://www.imagemagick.org/script/index.php) installed; binaries available in the Path
  -  [ffmpeg](https://www.ffmpeg.org/) installed; binaries available in the Path

  
Usage - prepare panoramas
-------------------------

  -   Copy images belonging to a panorama into a directory
  -   Copy `pano-smaller.sh` into this directory
  -   Launch

  
Usage - prepare video thumbnails
--------------------------------
  - `cd` into the directory of vide files.
  - Launch `collect-video-info.sh` to traverse and collect various details of the video files. Collected info is stored in files next to the original video.
  - Launch `make-video-tmbdir.sh` to create thumbnails (compressed versions) for videos.
  
  
  