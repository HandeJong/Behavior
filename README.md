# Behavior
Matlab scripts for analysis of mouse behavior.

Use bobserve_import to import X and Y coordinates from Biobserve into Matlab.

[trace, distance]=biobserve_import('filename.csv','player');
  -> Will display a playback of the locomotor trace. Use space and +/- for play/pause and to adjust playback speed.
  
[trace, distance]=biobserve_import('filename.csv','movement_corr',5);
  -> Will set the movement correction to 5 pixels.
  
For more options type:
help biobserve_import
