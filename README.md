# AviGlitch
[![Build Status](https://travis-ci.org/ucnv/aviglitch.svg?branch=master)](https://travis-ci.org/ucnv/aviglitch)

AviGlitch destroys your AVI files.

I can't explain why they're going to destroy their own data, but they do.

You can find a short guide at <http://ucnv.github.com/aviglitch/>.
It provides a way to manipulate the data in each AVI frames.
It will mostly be used for making datamoshing videos.
It parses only container level structure, doesn't parse codecs.

See following urls for details about visual glitch;

* vimeo <http://www.vimeo.com/groups/artifacts>
* wikipedia <http://en.wikipedia.org/wiki/Compression_artifact>

## Usage

```ruby
  require 'aviglitch'

  avi = AviGlitch.open('/path/to/your.avi')
  avi.glitch(:keyframe) do |data|
    data.gsub(/\d/, '0')
  end
  avi.output('/path/to/broken.avi')
```

This library also includes a command line tool named `datamosh`.
It creates the keyframes removed video.

```sh
  $ datamosh /path/to/your.avi -o /path/to/broken.avi
```

## Installation

```sh
  gem install aviglitch
```

## Copyright

Copyright (c) 2009 - 2014 ucnv. See LICENSE for details.
