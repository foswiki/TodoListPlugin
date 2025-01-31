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

package Foswiki::Plugins::TodoListPlugin::Core;

=begin TML

---+ package Foswiki::Plugins::TodoListPlugin::Core

core class for this plugin

an singleton instance is allocated on demand

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();
use Error qw(:try);

use constant TRACE => 0; # toggle me

=begin TML

---++ ClassMethod new() -> $core

creates the core object

=cut

sub new {
  my $class = shift;
  my $session = shift;

  my $this = bless({
    session => $session,
    metaDataName => $Foswiki::cfg{TodoListPlugin}{MetaData} || 'TODO',
    @_
  }, $class);

  return $this;
}

=begin TML

---++ ObjectMethod finish() 

called when the plugin is finished

=cut

sub finish {
  my $this = shift;

  undef $this->{_json};
}

=begin TML

---++ ObjectMethod TODOLIST($session, $params, $topic, $web) -> $html

handles the %TODOLIST macro

=cut

sub TODOLIST {
  my ($this, $session, $params, $topic, $web) = @_;

  my ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($web, $params->{topic} || $topic);
  return inlineError("topic not found") unless Foswiki::Func::topicExists($theWeb, $theTopic);

  my $request = Foswiki::Func::getRequestObject();
  my $rev = $params->{rev} // $request->param("rev");
  my ($meta) = Foswiki::Func::readTopic($web, $topic, $rev);

  my $wikiName = Foswiki::Func::getWikiName();
  return inlineError("access denied")
    unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $theTopic, $theWeb, $meta);

  Foswiki::Plugins::JQueryPlugin::createPlugin('TodoList');

  my $editMode = $params->{editmode} || "on";

  if (defined $rev) {
    $editMode = "off"
  } elsif ($editMode eq 'acl') {
    $editMode = $this->checkAccess($wikiName, $theWeb, $theTopic, $meta);
  } else {
    $editMode = "off" 
      unless Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $theTopic, $theWeb, $meta);
  }

  my $listName = $params->{_DEFAULT} || $params->{list} || 'default';
  my $icon1 = $params->{icon} || $params->{icon1} || "fa-circle-o";
  my $icon2 = $params->{icon2} || "fa-check";
  my $icon3 = $params->{icon3} || "fa-times";
  my $size = $params->{size} || 80;
  my $values = Foswiki::Func::isTrue($params->{ternary}, 0) ? 3 : 2;

  my @html5Data = ();
  push @html5Data, $this->encodeHtml5('editmode', $editMode);
  push @html5Data, $this->encodeHtml5('topic', "$web.$topic");
  push @html5Data, $this->encodeHtml5('list', $listName);
  push @html5Data, $this->encodeHtml5('icon1', $icon1);
  push @html5Data, $this->encodeHtml5('icon2', $icon2);
  push @html5Data, $this->encodeHtml5('icon3', $icon3);
  push @html5Data, $this->encodeHtml5('values', $values);
  push @html5Data, $this->encodeHtml5('size', $size);

  my @result = ();
  push @result, '<div class="todoList" '.join(" ", @html5Data).'"><ul>';
  my @list = $this->getTodoList($meta, $listName);

  my $iconFormat = 
      "<i class='fa icon1 $icon1'></i>" .
      "<i class='fa icon2 $icon2'></i>" .
      "<i class='fa icon3 $icon3'></i>";

  foreach my $item (@list) {
    my @itemHtml5 = ();
    foreach my $key (keys %$item) {
      next if $key =~ /^(author|date|createauthor|createdate)$/;
      push @itemHtml5, $this->encodeHtml5($key, $item->{$key});
    }

    my $text = $meta->renderTML($item->{text});
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    my $class = "todoItem value_".(int($item->{value} // 0));

    my $line = "<li class='$class'"
      . join(" ", @itemHtml5) . ">"
      . $iconFormat
      . "<span>$text</span>"
      . '</li>';

    push @result, $line;
  }

  if ($editMode eq "on") {
    push @result, "<li class='todoAddItem'>"
      . "<i class='fa icon1 $icon1'></i>" 
      . "<input type='text' name='text' size='$size' class='todoListInput foswikiHideOnPrint' placeholder='%MAKETEXT{\"add a todo\"}%'/>"
      . '</li>';
  }
  push @result, '</ul>';
  push @result, '</div>';

  return join("\n", @result);
}

=begin TML

---++ ObjectMethod encodeHtml5($key, $val)  -> $html5DataString

converts the given key-value pair into HTML5 data attributes

=cut

sub encodeHtml5 {
  my ($this, $key, $val) = @_;

  if (ref($val)) {
    $val = $this->json->encode($val);
  } else {
    $val = Foswiki::entityEncode($val, "\n");
  }

  return "data-$key='$val'";
}

=begin TML

---++ ObjectMethod checkAccess($wikiName, $web, $topic, $meta) -> $editMode

returns the edit mode for a todolist in acl mode

=cut

sub checkAccess {
  my ($this, $wikiName, $web, $topic, $meta) = @_;

  ($meta) = Foswiki::Func::readTopic($web, $topic) unless $meta;

  _writeDebug("called checkAccess($wikiName, $web, $topic)");

  return "off"
    unless Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web, $meta);

  return "on" 
    if Foswiki::Func::checkAccessPermission('TODOLISTCHANGE', $wikiName, undef, $topic, $web, $meta);

  _writeDebug("... no TODOLISTCHANGE rights");

  return "check"
    if Foswiki::Func::checkAccessPermission('TODOLISTCHECK', $wikiName, undef, $topic, $web, $meta);

  _writeDebug("... no TODOLISTCHECK rights");

  return "off";
}

=begin TML

---++ ObjectMethod json()  -> $json

returns a JSON delegate object

=cut

sub json {
  my $this = shift;

  $this->{_json} //= JSON->new->allow_nonref(1);
  return $this->{_json};
}

=begin TML

---++ ObjectMethod getTodoList($meta, $listName)  -> @list

returns an array of list items for the given list

=cut

sub getTodoList {
  my ($this, $meta, $listName) = @_;

  $listName //= 'default';
  
  my @list = 
    sort {($a->{index}//0) <=> ($b->{index}//0) || $a->{name} cmp $b->{name}} 
    grep {$_->{list} eq $listName} 
    $meta->find($this->{metaDataName});

  return @list;
}

=begin TML

---++ ObjectMethod getTodoItem($meta, $name) -> $item

returns the meta data for a single todo list item of the given name

=cut

sub getTodoItem {
  my ($this, $meta, $name) = @_;

  return $meta->get($this->{metaDataName}, $name);
}

=begin TML

---++ ObjectMethod jsonRpcReadList($request)  -> $result

handles the readList json-rpc handler

=cut

sub jsonRpcReadList {
  my ($this, $request) = @_;

  my $web //= $this->{session}{webName};
  my $topic //= $this->{session}{topicName};
  my $listName = $request->param("list");
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $topic, $web, $meta);

  my @list = $this->getTodoList($meta, $listName);
  foreach my $item (@list) {
    my $text = $item->{text};
    $text = $meta->expandMacros($text) if $text =~ /%/;
    $text = $meta->renderTML($text);
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $item->{_rendered} = $text;
  }
  return \@list;
}

=begin TML

---++ ObjectMethod jsonRpcSaveList($request) -> $result

handles the saveList json-rpc handler

=cut

sub jsonRpcSaveList {
  my ($this, $request) = @_;

  _writeDebug("called jsonRpcSaveList()");

  my $web //= $this->{session}{webName};
  my $topic //= $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web, $meta);

  my $listName = $request->param("list") || "default";
  my $sorting = $request->param("sorting") || [];
  my $clientId = $request->param("clientId");

  throw Error::Simple("sorting missing") unless @$sorting;

  foreach my $record (@$sorting) {
    my $item = $this->getTodoItem($meta, $record->{name});
    if ($item) {
      $item->{index} = $record->{pos};

      # not setting the below values as thats not particularly usefull
      #$item->{author} = Foswiki::Func::getCanonicalUserID();
      #$item->{date} = time();

      delete $item->{_rendered};
      $meta->putKeyed($this->{metaDataName}, $item);
    } else {
      print STDERR "WARNING: record $record->{name} not found in meta\n";
    }
  }

  $meta->save();

  _publish("$web.$topic", {
    type => "saveList",
    clientId => $clientId,
    data => {
      web => $web,
      topic => $topic,
      list => $listName    
    }
  });

  return "ok";
}

=begin TML

---++ ObjectMethod jsonRpcSaveTodo($request) -> $result

handles the saveTodo json-rpc handler

=cut

sub jsonRpcSaveTodo {
  my ($this, $request) = @_;

  _writeDebug("called jsonRpcSaveTodo()");

  my $web //= $this->{session}{webName};
  my $topic //= $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web, $meta);

  my $name = $request->param("name");
  my $listName = $request->param("list") || "default";
  my $text = $request->param("text");
  my $clientId = $request->param("clientId");
  my $value = int($request->param("value") // 0);
  my $pos = $request->param("pos");
  my @list = $this->getTodoList($meta, $listName);
  my $item = $name ? $this->getTodoItem($meta, $name) : undef;

  if ($item) {
    $item->{text} = $text if defined $text;
    $item->{value} = $value;
    $item->{date} = time();
    $item->{list} = $listName;
    $item->{author} = Foswiki::Func::getCanonicalUserID();

    if (defined $pos) {
      if ($pos < 0) {
        $pos = @list ? $list[-1]{index} +1 : 0;
      }

      my $newIndex = 0;
      foreach my $otherItem (@list) {
        next if $otherItem->{name} eq $item->{name};
        if ($newIndex eq $pos) {
          $item->{index} = $pos;
          $newIndex++;
        }
        $otherItem->{index} = $newIndex++;
      }
    }

    _writeDebug("... updating item $item->{name}, index=$item->{index}");
  } else {
    return unless $text;

    $pos = @list ? $list[-1]{index} +1 : 0;

    $item = $this->newTodoItem($meta, {
      index => $pos,
      list => $listName,
      text => $text,
      value => $value,
    });
  }

  delete $item->{_rendered};
  $meta->putKeyed($this->{metaDataName}, $item);
  $meta->save();

  my $rendered = $item->{text};
  $rendered = $meta->expandMacros($rendered) if $rendered =~ /%/;
  $rendered = $meta->renderTML($rendered);
  $rendered =~ s/^\s+//;
  $rendered =~ s/\s+$//;
  $item->{_rendered} = $rendered;

  _publish("$web.$topic", {
    type => "saveTodo",
    clientId => $clientId,
    data => {
      web => $web,
      topic => $topic,
      list => $listName    
    }
  });

  return $item;
}

=begin TML

---++ ObjectMethod newTodoItem($meta, $params)  -> $todoItem

creates a new todo item

=cut

sub newTodoItem {
  my ($this, $meta, $params) = @_;

  my $item;
  %{$item} = %{$params};
  $item->{name} //= $this->getNewId($meta);
  $item->{date} //= time();
  $item->{createdate} //= time();
  $item->{author} //= Foswiki::Func::getCanonicalUserID();
  $item->{createauthor} //= Foswiki::Func::getCanonicalUserID();

 _writeDebug("... new item name=$item->{name}, index=$item->{index}");

  return $item;
}


=begin TML

---++ ObjectMethod getNewId($meta) -> $idString

returns the next best name id for a new todo item

=cut

sub getNewId {
  my ($this, $meta) = @_;

  my $maxId = 0;

  foreach my $item ($meta->find($this->{metaDataName})) {
    $item->{name} =~ /^id(\d+)$/;
    my $id = $1 // 0;
    $maxId = $id if $id > $maxId;
  }

  $maxId++;

  return "id$maxId";
}

=begin TML

---++ ObjectMethod jsonRpcDeleteTodo($request) -> $resukt

handles the deleteTodo json-rpc handler

=cut

sub jsonRpcDeleteTodo {
  my ($this, $request) = @_;

  my $web //= $this->{session}{webName};
  my $topic //= $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web, $meta);

  my $name = $request->param("name") || '';
  my $listName = $request->param("list") || "default";
  my $clientId = $request->param("clientId");

  $meta->remove($this->{metaDataName}, $name);
  $meta->save();

  _publish("$web.$topic", {
    type => "deleteTodo",
    clientId => $clientId,
    data => {
      web => $web,
      topic => $topic,
      list => $listName    
    }
  });

  return 1;
}

=begin TML

---++ ObjectMethod solrIndexTopicHandler($indexer, $doc, $web, $topic, $meta, $text) 

hooks into SolrPlugin and indexes all todo meta data

=cut

sub solrIndexTopicHandler {
  my ($this, $indexer, $doc, $web, $topic, $meta, $text) = @_;

  my @list = $meta->find($this->{metaDataName});
  return unless scalar(@list);
  _writeDebug("found todos");

  my @commonFields = ();
  for my $field (qw(tag category webcat)) {
    my @vals = $doc->values_for($field);
    #print STDERR "field=$field, vals=@vals\n";
    push @commonFields, [$field => $_] foreach @vals;
  }

  my @aclFields = $indexer->getAclFields($web, $topic, $meta);
  push @commonFields, @aclFields if @aclFields;

  my $webtopic = "$web.$topic";
  $webtopic =~ s/\//./g;

  my $url = $indexer->getScriptUrlPath($web, $topic, 'view');
  my $containerTitle = Foswiki::Func::getTopicTitle($web, $topic, undef, $meta);

  foreach my $record (@list) {

    $indexer->log("Indexing todo $record->{name} at $web.$topic");

    # create a solr doc for each record
    my $doc = $indexer->newDocument();

    $doc->add_fields(
      'id' => $webtopic . '#todo#' . $record->{name},
      'type' => 'todo',
      'icon' => 'fa-check-circle',
      'name' => $record->{name},
      'web' => $web,
      'topic' => $topic,
      'webtopic' => $webtopic,
      'url' => $url,

      'container_id' => $web . '.' . $topic,
      'container_web' => $web,
      'container_topic' => $topic,
      'container_url' => $url,
      'container_title' => $containerTitle
    );

    # add extra fields, i.e. ACLs
    $doc->add_fields(@commonFields) if @commonFields;

    my $author = Foswiki::Func::getWikiName($record->{author});
    my $createAuthor = Foswiki::Func::getWikiName($record->{createauthor});
    
    my $text = $indexer->plainify($record->{text}); 
    my $title = substr($text, 0, 75);
    $title .= "..." if $title ne $text;

    $doc->add_fields(

      "author" => $author,
      "author_title" => Foswiki::Func::getTopicTitle($Foswiki::cfg{UsersWebName}, $author),
      "date" => Foswiki::Time::formatTime($record->{date}, '$iso', 'gmtime'),

      "createauthor" => $createAuthor,
      "createauthor_title" => Foswiki::Func::getTopicTitle($Foswiki::cfg{UsersWebName}, $createAuthor),
      "createdate" => Foswiki::Time::formatTime($record->{createdate}, '$iso', 'gmtime'),

      "title" => $title,
      "text" => $record->{text},
      "field_Value_s" => int($record->{value} // 0),
    );

    try {
      $indexer->add($doc);
    }
    catch Error::Simple with {
      my $e = shift;
      $indexer->log("ERROR: " . $e->{-text});
    };
  }
}

=begin TML

---++ ObjectMethod beforeSaveHandler($web, $topic, $meta) 

converts an inline bullet list into a todo list stored in meta data

=cut

sub beforeSaveHandler {
  my ($this, $web, $topic, $meta) = @_;

  my $text = $meta->text();

  my $removed = {};
  $text = _takeOutBlocks($text, 'verbatim', $removed);

  $text =~ s/%STARTTODOLIST%(.*?)%ENDTODOLIST%/$this->convertTodoList($meta, $1)/gse;

  _putBackBlocks(\$text, 'verbatim', $removed);

  $meta->text($text);
}

=begin TML

---++ ObjectMethod convertTodoList($meta, $text) 

=cut

sub convertTodoList {
  my ($this, $meta, $text) = @_;

  my $listName = "id". (time() + int(rand(10000)));
  my $index = 0;

  foreach my $line (split(/\n/, $text)) {
    if ($line =~ /^   \*\s+(.*?)\s*$/) {
      my $item = $this->newTodoItem($meta, {
        index => $index++,
        list => $listName,
        text => $1,
        value => 0
      });
      $meta->putKeyed($this->{metaDataName}, $item);
    }
  }

  return "%TODOLIST{\"$listName\"}%";
}

### static helpers

sub _writeDebug {
  return unless TRACE;
  #Foswiki::Func::writeDebug("TodoListPlugin::Core - $_[0]");
  print STDERR "TodoListPlugin::Core - $_[0]\n";
}

sub _inlineError {
  return "<span class='foswikiAlert'>".$_[0]."</span>";
}

sub _publish {
  my ($channel, $message) = @_;

  if (exists $Foswiki::cfg{Plugins}{WebSocketPlugin}{Enabled} && $Foswiki::cfg{Plugins}{WebSocketPlugin}{Enabled}) {
    require Foswiki::Plugins::WebSocketPlugin;
    return Foswiki::Plugins::WebSocketPlugin::publish($channel, $message);
  }
}

sub _takeOutBlocks {
  my ($text, $tag, $map) = @_;

  return '' unless defined $text;
  return $text unless $text =~ /\b$tag\b/;

  return Foswiki::takeOutBlocks($text, $tag, $map) if defined &Foswiki::takeOutBlocks;
  return $Foswiki::Plugins::SESSION->renderer->takeOutBlocks($text, $tag, $map);
}

sub _putBackBlocks {
  my ($text, $tag, $map) = @_;

  return Foswiki::putBackBlocks($text, $map, $tag) if defined &Foswiki::putBackBlocks;
  return $Foswiki::Plugins::SESSION->renderer->putBackBlocks($text, $map, $tag);
}

1;
