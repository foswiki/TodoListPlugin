# Plugin for Foswiki - The Free and Open Source Wiki, https://foswiki.org/
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

package Foswiki::Plugins::TodoListPlugin;

=begin TML

---+ package Foswiki::Plugins::TodoListPlugin

plugin class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Plugins::JQueryPlugin ();

our $VERSION = '1.30';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'simple todo lists';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler('TODOLIST', sub { return getCore()->TODOLIST(@_); });
  Foswiki::Plugins::JQueryPlugin::registerPlugin('TodoList', 'Foswiki::Plugins::TodoListPlugin::TodoList');

  Foswiki::Contrib::JsonRpcContrib::registerMethod(
    "TodoListPlugin",
    "readList",
    sub {
      my $session = shift;
      return getCore($session)->jsonRpcReadList(@_);
    }
  );

  Foswiki::Contrib::JsonRpcContrib::registerMethod(
    "TodoListPlugin",
    "saveTodo",
    sub {
      my $session = shift;
      return getCore($session)->jsonRpcSaveTodo(@_);
    }
  );

  Foswiki::Contrib::JsonRpcContrib::registerMethod(
    "TodoListPlugin",
    "saveList",
    sub {
      my $session = shift;
      return getCore($session)->jsonRpcSaveList(@_);
    }
  );

  Foswiki::Contrib::JsonRpcContrib::registerMethod(
    "TodoListPlugin",
    "deleteTodo",
    sub {
      my $session = shift;
      return getCore($session)->jsonRpcDeleteTodo(@_);
    }
  );

  if ($Foswiki::Plugins::VERSION > 2.0) {
    my $metaDataName = $Foswiki::cfg{TodoListPlugin}{MetaData} || 'TODO';
    Foswiki::Func::registerMETA($metaDataName, 
      alias => lc($metaDataName), 
      many => 1,
      form => "$Foswiki::cfg{SystemWebName}.TodoListForm",
      ignoreSolrIndex => 1,
    );
  }

  if (exists $Foswiki::cfg{Plugins}{SolrPlugin} && $Foswiki::cfg{Plugins}{SolrPlugin}{Enabled}) {
    require Foswiki::Plugins::SolrPlugin;
    Foswiki::Plugins::SolrPlugin::registerIndexTopicHandler(sub {
      return getCore()->solrIndexTopicHandler(@_);
    });
  }

  return 1;
}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )

convert inline todolists into meta data

=cut

sub beforeSaveHandler {
  my ($text, $topic, $web, $meta) = @_;

  getCore()->beforeSaveHandler($web, $topic, $meta);
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {
  $core->finish() if $core;
  undef $core;
}

=begin TML

---++ getCore() -> $core

returns a singleton Foswiki::Plugins::TodoListPlugin::Core object for this plugin

=cut

sub getCore {
  my $session = shift || $Foswiki::Plugins::SESSION;

  unless (defined $core) {
    require Foswiki::Plugins::TodoListPlugin::Core;
    $core = Foswiki::Plugins::TodoListPlugin::Core->new($session);
  }
  return $core;
}

1;
