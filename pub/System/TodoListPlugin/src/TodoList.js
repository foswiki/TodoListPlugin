/*
 * TodoListPlugin 0.20
 *
 * (c)opyright 2024-2025 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed under the GPL license http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

(function($) {
  /***************************************************************************
   * globals
   */
  var defaults = {
    editmode: "on",
    size: 80,
    debug: false
  };

  /***************************************************************************
   * class definition
   */
  function TodoList(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({
      topic: foswiki.getPreference("WEB") + "." + foswiki.getPreference("TOPIC")
    }, defaults, opts);
    self.init();

    //self.log("created todolist", self);
  }

  /***************************************************************************
   * logging
   */
  TodoList.prototype.log = function() {
    var self = this, args;

    if (typeof(console) !== 'undefined' && self.opts.debug) {
      args = $.makeArray(arguments);
      args.unshift("TODOLIST: ");
      console.log.apply(self, args); // eslint-disable-line no-console
    }
  };

  /***************************************************************************
   * init todolist 
   */
  TodoList.prototype.init = function() {
    var self = this;

    self.list = self.elem.children("ul:first");

    self.elem.on("reload",function() {
      self.reload();
    });

    if (foswiki.eventClient) {
      foswiki.eventClient.bind("saveList", function(message) {
        if (message.clientId !== foswiki.eventClient.id && message.data.list === self.opts.list) {
          self.log("saveList event for",self.opts.list);
          self.reload();
        }
      });
      foswiki.eventClient.bind("saveTodo", function(message) {
        if (message.clientId !== foswiki.eventClient.id && message.data.list === self.opts.list) {
          self.log("saveTodo event for",self.opts.list);
          self.reload();
        }
      });
      foswiki.eventClient.bind("deleteTodo", function(message) {
        if (message.clientId !== foswiki.eventClient.id && message.data.list === self.opts.list) {
          self.log("deleteTodo event for",self.opts.list);
          self.reload();
        }
      });
    }

    self.list.children(".todoItem").each(function() {
      self.createTodoItem(this);
    });


    if (self.opts.editmode === "on") {

      // add input
      self.input = self.elem.find(".todoListInput");
      self.input.on("keydown", function(ev) {
        var val = self.input.val(), item;

        if (ev.key === "Enter" && val !== "") {
          self.input.val("").focus();
          item = self.createTodoItem(undefined, {
            text: val
          });
          item.elem.insertBefore(self.input.parent());
          item.save();
          return false;
        }
      });


      // make it sortable
      self.list.sortable({
        connectWith: ".todoList > ul",
        items: "> li.todoItem",
        //axis: "y",
        distance: 5,
        tolerance: "pointer",
        placeholder: "ui-sortable-placeholder todolistPlaceholder",
        forcePlaceholderSize: true,
        cursor: "move",

        start: function(ev, ui) {
          self._beforeCountItems = self.length();
          self.log("before count items=",self._beforeCountItems,"in",self.opts.list);
        },

        update: function(ev, ui) {
          var sender = ui.sender,
            item = ui.item.data("todoItem"),
            afterCountItems = self.length();

          self.log("got an update in " + self.opts.list,"countItems=",afterCountItems);

          if (self._beforeCountItems > afterCountItems) {
            self.log("detected a remove ... ignoring");
            return;
          }

          self.log("item list=",item.opts.list,"self list=",self.opts.list);

          if (item.opts.list === self.opts.list) {
            self.save().always(function() {
              self.reload();
            });
          } else {
            item.set("list", self.opts.list)
            item.save().always(function() {
              self.reload();
            });
          }
        }
      });
    }
  };

  /***************************************************************************
   * create a new todo item for this list
   */
  TodoList.prototype.createTodoItem = function(elem, opts) {
    var self = this, item;

    opts = opts || {};

    opts.topic = self.opts.topic;
    opts.list = self.opts.list;
    opts.editmode = self.opts.editmode;
    opts.icon1 = self.opts.icon1;
    opts.icon2 = self.opts.icon2;
    opts.icon3 = self.opts.icon3;
    opts.values = self.opts.values;
    opts.size = self.opts.size;

    return new TodoItem(elem, opts);
  };

  /***************************************************************************
   * returns the number of current todo items in the list
   */
  TodoList.prototype.length = function() {
    var self = this;

    return self.list.children(".todoItem:not(.ui-sortable-placeholder)").length;
  };

  /***************************************************************************
   * save the current sorting of the list
   */
  TodoList.prototype.save = function() {
    var self = this, sorting = [], data;

    if (self.opts.editmode !== "on") return $.Deferred().reject("not editable");

    self.list.children(".todoItem").each(function() {
      var elem = $(this);

      sorting.push({
        pos: elem.index(),
        name: elem.data("name"),
      });
    });

    self.log("saving list",self.opts.list, "with sorting",sorting);

    data = {
      topic: self.opts.topic,
      list: self.opts.list,
      sorting: sorting,
    };

    if (foswiki.eventClient) {
      data.clientId = foswiki.eventClient.id;
    }

    self.elem.block({message: null});

    return foswiki.jsonRpc({
      namespace: "TodoListPlugin",
      method: "saveList",
      params: data
    }).always(function() {
      self.elem.unblock();
    }).fail(function(xhr) {
      var response = xhr.responseJSON;
      $.pnotify({
        type: "error",
        title: "Error "+response.error.code,
        text: response.error.message
      });
    });
  };

  /***************************************************************************
   * reload a list, mostly triggered by an event handler
   */
  TodoList.prototype.reload = function() {
    var self = this;

    self.log("reloading list",self.opts.list);

    return foswiki.jsonRpc({
      namespace: "TodoListPlugin",
      method: "readList",
      params: {
        topic: self.opts.topic,
        list: self.opts.list
      }
    }).done(function(response) {
      var inputContainer = self.input.parent();
      self.list.children(".todoItem").remove();
      response.result.forEach(function(data) {
        var item;

        data.topic = self.opts.topic;
        data.list = self.opts.list;

        item = self.createTodoItem(undefined, data)
        item.elem.insertBefore(inputContainer);
      });
    }).fail(function(xhr) {
      var response = xhr.responseJSON;
      $.pnotify({
        type: "error",
        title: "Error "+response.error.code,
        text: response.error.message
      });
    });
  };

  /***************************************************************************
   * make it a jQuery plugin
   */
  $.fn.todoList = function(opts) {
    return this.each(function() {
      if (!$.data(this, "todoList")) {
        $.data(this, "todoList", new TodoList(this, opts));
      }
    });
  };

  /***************************************************************************
   * enable declarative widget instanziation
   */
  $(".todoList:not(.inited)").livequery(function() {
    var $this = $(this),
      opts = $.extend({}, defaults, $this.data());

    $this.addClass("inited").todoList(opts);
  });
})(jQuery);
