### 0.2.2 / 2024-07-20

* Added option to set a custom directory for temporary files that internally duplicate input files.
* Also added an option for the custom temp directory in the datamosh cli.
* Some improvements regarding internal temporary files.

### 0.2.0 / 2021-09-13

* Support for AVI2.0 formatted files. Now this library can handle files larger than 1GB.
* Added methods to Frames, including #index, #rindex, #first_of, and #last_of
* Removed warnings for the file size getting large.
* Added the class AviGlitch::Avi which manages binary RIFF-AVI data.
* A lot of internal changes.

### 0.1.6 / 2021-08-21

* Removed obsolete dependencies.

### 0.1.5 / 2014-12-12

* Fix Frames#concat and two other method to return self.
* Some internal changes.

### 0.1.4 / 2014-04-10

* Added an enumerator style on AviGlitch::Base#glitch and
AviGlitch::Frames#each
* Added AviGlitch::Base#remove_all_keyframes!
* Renamed #clear_keyframes! to #mutate_keyframes_into_deltaframes!
* Improved the processing speed in some measure.
* Some minor fixes.

### 0.1.3 / 2011-08-19

* Added has_keyframe? method to AviGlitch::Base
* Added a --fake option to datamosh cli.

### 0.1.2 / 2011-04-10

* Fix to be able to handle data with offsets from 0 of the file.
* Added clear_keyframes! method to AviGlitch::Frames and AviGlitch::Base.
* Changed to be able to access frame's meta data.
* Changed datamosh command to handle wildcard char.

### 0.1.1 / 2010-09-09

* Fixed a bug with windows.
* Some tiny fixes.

### 0.1.0 / 2010-07-09

* Minor version up.
* Fixed bugs with Ruby 1.8.7.
* Fixed the synchronization problem with datamosh cli.

### 0.0.3 / 2010-07-07

* Changed AviGlitch::Frames allowing to slice and concatenate frames
(like Array).
* Changed datamosh cli to accept multiple files.

### 0.0.2 / 2010-05-17

* Removed AviGlitch#new. Use AviGlitch#open instead of #new.
* Added warning for a large file.
* Changed datamosh command interface.
* Changed the library file layout.
* And tiny internal changes.

### 0.0.1 / 2009-08-01

* initial release

