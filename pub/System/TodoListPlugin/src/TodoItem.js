/*
 * TodoItem 0.11
 *
 * (c)opyright 2024 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed under the GPL license http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

(function($) {
  var defaults = {
    values: 2,
    size: 80,
    text: "",
    editmode: "on",
    debug: false
  };

  /***************************************************************************
   * class definition
   */
  function TodoItem(elem, opts) {
    var self = this;

    if (typeof(elem) === 'undefined') {
      self.opts = $.extend({}, defaults, opts);
      self.createView();
    } else {
      self.elem = $(elem);
      self.view = self.elem.children("span:first");
      self.opts = $.extend({}, defaults, self.elem.data(), opts);
    }

    self.elem.data("todoItem", self);

    if (self.opts.editmode === "on") {
      self.elem.on("dblclick", function() {
        self.displayEditor();
      });
    }

    if (self.opts.editmode !== "off") {
      self.elem.on("click", "i", function(ev) {
        var val = parseInt(self.get("value") || 0),
          newVal = val + (ev.shiftKey ? -1 : 1);

        if (newVal < 0) {
          newVal = self.opts.values -1;
        } else if (newVal >= self.opts.values) {
          newVal = 0;
        }

        self.log("clicked on item. val=",val,"newVal=",newVal);

        self.elem.removeClass("value_"+val);
        self.elem.addClass("value_"+newVal);
        self.set("value", newVal);
        self.save();
      });
    }
  }

  /***************************************************************************
   * logging
   */
  TodoItem.prototype.log = function() {
    var self = this, args;

    if (typeof(console) !== 'undefined' && self.opts.debug) {
      args = $.makeArray(arguments);
      args.unshift("TODOITEM: ");
      console.log.apply(self, args); // eslint-disable-line no-console
    }
  };

  /***************************************************************************
   * createEdit
   */
  TodoItem.prototype.createEditor = function() {
    var self = this;

    if (self.opts.editmode !== "on") return;

    if (typeof(self.input) !== 'undefined') return;

    self.input = $("<input />")
      .attr({
        type: "search",
        class: "todoListInput",
        size: self.opts.size,
        name: self.opts.name
      })
      .val(self.opts.text);

    self.input.on("keydown", function(ev) {

      if (ev.key === "ArrowUp" || (ev.key === "Tab" && ev.shiftKey)) {
        self.navigate(-1);
        return false;
      }

      if (ev.key === "ArrowDown" || (ev.key === "Tab" && !ev.shiftKey)) {
        self.navigate(1);
        return false;
      }

      if (ev.key === "Escape") {
        self.input.val(self.opts.text);
        self.displayView();
        return false;
      } 

      if (ev.key === "Enter") {
        self.saveOrRemove();
        return false;
      }
    });

    self.input.on("blur", function() {
      if (self.input.is(":visible")) {
        self.saveOrRemove();
      }
      return false;
    });

    self.input.appendTo(self.elem);

    return self.input;
  };

  /***************************************************************************
   * create an html representatin
   */
  TodoItem.prototype.createView = function() {
    var self = this,
      val = parseInt(self.get("value") || 0, 10);

    self.elem = $("<li />")
      .addClass("todoItem")
      .data(self.opts);

    self.elem.addClass("value_"+val);

    $("<i />")
      .addClass("fa icon1")
      .addClass(self.opts.icon1)
      .appendTo(self.elem);

    $("<i />")
      .addClass("fa icon2")
      .addClass(self.opts.icon2)
      .appendTo(self.elem);

    $("<i />")
      .addClass("fa icon3")
      .addClass(self.opts.icon3)
      .appendTo(self.elem);

    if (typeof(self.opts._rendered) === 'undefined') {
      self.view = $("<span />").text(self.opts.text)
    } else {
      self.view = $("<span />").html(self.opts._rendered)
    }
    self.view.appendTo(self.elem);

    return self.view;
  };

  /***************************************************************************
   * naviagte to an adjacent TodoItem in the same list
   */
  TodoItem.prototype.navigate = function(direction) {
    var self = this,
      pos = self.elem.index() + direction,
      otherElem;

    if (pos < 0) return;

    otherElem = self.elem.parent().children(".todoItem").eq(pos);

    if (!otherElem.length) return;

    self.saveOrRemove().done(function() {
      var todoItem = otherElem.data("todoItem");
      if (todoItem) {
        todoItem.displayEditor();
      }
    });
  };

  /***************************************************************************
   * toggle edit mode
   */
  TodoItem.prototype.displayEditor = function() {
    var self = this;

    if (self.opts.editmode !== "on") return;

    self.view.hide();
    self.createEditor();
    self.input.show().focus();
  };

  /***************************************************************************
   * toggle view mode
   */
  TodoItem.prototype.displayView = function() {
    var self = this;

    if (typeof(self.input) !== 'undefined') {
      self.input.hide();
    }
    self.view.show();
    self.view.removeAttr("style"); // work around old display:inlien style being applied by jquery automatically
  };

  /***************************************************************************
   * set properties
   */
  TodoItem.prototype.set = function(key, val) {
    var self = this;

    self.opts[key] = val;
    self.elem.data(key, val);
  };

  /***************************************************************************
   * get properties
   */
  TodoItem.prototype.get = function(key) {
    var self = this;

    return self.opts[key];
  };

  /***************************************************************************
   * get todoList this item is a part of
   */
  TodoItem.prototype.getTodoList = function() {
    var self = this;

    return self.elem.parents(".todoList:first").data("todoList");
  };

  /***************************************************************************
   * saves or removes the current item based on its value
   */
  TodoItem.prototype.saveOrRemove = function() {
    var self = this,
        val = self.input.val().trim();

    if (val === '') {
      return self.remove();
    } 

    return self.save();
  };

  /***************************************************************************
   * destroy this instance and its dom representation
   */
  TodoItem.prototype.remove = function() {
    var self = this, data;

    data = {
      topic: self.opts.topic,
      list: self.opts.list,
      name: self.opts.name,
    }

    if (foswiki.eventClient) {
      data.clientId = foswiki.eventClient.id;
    }

    self.elem.block({message: null});
    return foswiki.jsonRpc({
      namespace: "TodoListPlugin",
      method: "deleteTodo",
      params: data
    }).always(function() {
      self.elem.unblock();
    }).done(function() {
      self.elem.remove();
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
   * save results into the todolist
   */
  TodoItem.prototype.save = function() {
    var self = this, data;

    self.log("called save");

    if (self.opts.editmode === "off") return $.Deferred().reject("not editable");


    if (typeof(self.input) !== 'undefined' 
        && self.opts.text === self.input.val().trim()
        && self.elem.data("value") === self.opts.value
      ) {
      self.displayView();
      return $.Deferred().resolve();
    } 

    data = {
      topic: self.opts.topic,
      list: self.opts.list,
      name: self.opts.name,
      pos: self.elem.index(),
      value: self.opts.value
    };


    if (foswiki.eventClient) {
      data.clientId = foswiki.eventClient.id;
    }

    if (typeof(self.input) === 'undefined') {
      data.text = self.opts.text.trim();
    } else {
      data.text = self.input.val().trim();
    }

    self.elem.block({message: null});
    return foswiki.jsonRpc({
      namespace: "TodoListPlugin",
      method: "saveTodo",
      params: data
    }).always(function() {
      self.elem.unblock();
    }).done(function(response) {
      var result = response.result;

      self.set("name", result.name);
      self.set("list", result.list);
      self.set("value", result.value);
      self.set("text", result.text);
      self.set("_rendered", result._rendered);

      if (typeof(result._rendered) === 'undefined') {
        self.view.text(result.text);
      } else {
        self.view.html(result._rendered)
      }
      self.displayView();
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
   * export
   */

  if (typeof(module) !== 'undefined') {
    module.exports = TodoItem;
  } else {
    window.TodoItem = TodoItem;
  }
})(jQuery);
