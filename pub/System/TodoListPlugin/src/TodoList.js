/*
 * TodoListPlugin 0.41
 *
 * (c)opyright 2024-2026 Michael Daum http://michaeldaumconsulting.com
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

    self.list.children(".todoItem:not(.todoEmptyItem)").each(function() {
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
        placeholder: "ui-sortable-placeholder todoListPlaceholder",
        //forceHelperSize: true,
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
          self.log("item data=",item);

          if (self._beforeCountItems > afterCountItems) {
            self.log("detected a remove ... ignoring");
            self.updateCounter();
            return;
          }

          self.log("item from list=",item.opts.list,"to list=",self.opts.list);

          if (item.opts.list === self.opts.list) {
            self.save();
          } else {
            item.set("list", self.opts.list)
            item.save().always(function() {
              //self.reload();
            });
          }
        }
      });
    }
    self.initEvents();
  };

  // update counter element *********************************************
  TodoList.prototype.updateCounter = function() {
    var self = this;

    self.elem.find(".todoListCounter").text(self.length());
  };

  // attaching to websocket events **************************************
  TodoList.prototype.initEvents = function () {
    var self = this;

    if (self._initedEvents) {
      return;
    }

    if (!foswiki.eventClient) {
      $(document).one("eventClient", function() {
        self.initEvents();
      });
      return;
    }

    self._initedEvents = true;
    foswiki.eventClient.bind("saveList saveTodo deleteTodo deleteTodos", function(message) {
      if (message.clientId !== foswiki.eventClient.id && message.data.list === self.opts.list) {
        self.log(`${message.type} event for`,self.opts.list);
        self.reload();
      }
    });
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

    return self.list.children(".todoItem:not(.ui-sortable-placeholder):not(.todoEmptyItem)").length;
  };

  /***************************************************************************
   * save the current sorting of the list
   */
  TodoList.prototype.save = function() {
    var self = this, sorting = [], data;

    if (self.opts.editmode !== "on") return $.Deferred().reject("not editable");

    self.list.children(".todoItem:not(.todoEmptyItem)").each(function() {
      var elem = $(this);

      sorting.push({
        pos: elem.index()-1,
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
    }).done(function(response) {
      self.render(response.result);
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

    foswiki.debounce(function() {
      self._reload()
    }, "TodoList_reload", 500)();
  };

  TodoList.prototype._reload = function() {
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
      self.render(response.result);
    }).fail(function(xhr) {
      var response = xhr.responseJSON;
      $.pnotify({
        type: "error",
        title: "Error "+response.error.code,
        text: response.error.message
      });
    });
  };

  TodoList.prototype.render = function(data) {
    var self = this;

    var inputContainer = self.input.parent();
    self.list.children(".todoItem:not(.todoEmptyItem)").remove();
    data.forEach(function(data) {
      var item;

      data.topic = self.opts.topic;
      data.list = self.opts.list;

      item = self.createTodoItem(undefined, data)
      item.elem.insertBefore(inputContainer);
    });

    self.updateCounter();
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
