# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TodoListPlugin is Copyright (C) 2024-2025 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TodoListPlugin::TodoList;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins ();
use Foswiki::Plugins::TodoListPlugin ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  return bless(
    $class->SUPER::new(
      $session,
      name => 'TodoList',
      version => $Foswiki::Plugins::TodoListPlugin::VERSION,
      author => 'Michael Daum',
      homepage => 'https://foswiki.org/Extensions/TodoListPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/TodoListPlugin/build',
      css => ['pkg.css'],
      javascript => ['pkg.js',],
      dependencies => ['JQUERYPLUGIN::EVENTCLIENT', 'pnotify', 'blockui','fontawesome', 'ui'],
    ),
    $class
  );
}

1;
