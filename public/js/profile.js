/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
Array.prototype.unique = function() {
  return this.filter(function (value, index, self) { 
    return self.indexOf(value) === index;
  });
}

var Profile = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",
    init: function(user_id = "", path = "") {
      this.user_id = user_id;
      this.path = path;
      this.activate_radios();
      this.activate_switch();
      this.activate_orcid_refresh();
    },
    activate_switch: function() {
      var self = this;
      $('#toggle-public').change(function() {
        $.ajax({
          method: "PUT",
          url: self.path + "/profile.json?user_id=" + self.user_id,
          dataType: "json",
          data: JSON.stringify({ is_public: $(this).prop('checked') })
        }).done(function(data) {
          
        });
      });
    },
    activate_radios: function(){
      var self = this;
      $('input.action-radio').change(function() {
          var action = $(this).attr("data-action"),
              label = $(this).parent();
              
          if($(this).attr("name") === "selection-all") {
              var ids = $.map($('[data-id]'), function(e) {
                return $(e).attr("data-id");
              }).unique().toString();
              $.ajax({
                  method: "PUT",
                  url: self.path + "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({
                    user_id: self.user_id,
                    ids: ids,
                    action: action
                  })
              }).done(function(data) {
                  $('label').each(function() {
                      $(this).removeClass("active");
                      if($('input:first-child', this).attr("data-action") === action) {
                          $(this).addClass("active");
                      }
                  });
              });
          } else {
              var id = $(this).attr("data-id");
              $.ajax({
                  method: "PUT",
                  url: self.path + "/user-occurrence/" + id + ".json",
                  dataType: 'json',
                  data: JSON.stringify({
                    user_id: self.user_id,
                    action: action
                  })
              }).done(function(data) {
                  label.parent().find("label").each(function() {
                      $(this).removeClass("active");
                  });
                  label.addClass("active");
              });
          }
      });
      $('button.remove').on('click', function() {
          var id = $(this).attr("data-id"),
              row = $(this).parents("tr");
          $.ajax({
              method: "DELETE",
              url: self.path + "/user-occurrence/" + id + ".json",
              data: JSON.stringify({ user_id: self.user_id })
          }).done(function(data) {
              row.fadeOut(250, function() {
                  $(this).remove();
                  if ($('button.remove').length === 0) {
                    location.reload();
                  }
              });
          });
      });
    },
    activate_orcid_refresh: function(){
      var self = this;
      $("div.orcid-refresh a").on("click", function() {
        $.ajax({
            method: "GET",
            url: self.path + "/orcid-refresh.json?user_id=" + self.user_id
        }).done(function(data) {
          $(".alert").alert().show();
          $(".alert").on('closed.bs.alert', function () {
            location.reload();
          });
        });
        return false;
      });
    }
  };

  return {
    init: function(user_id = "", path = "") {
      _private.init(user_id, path);
    }
  };

}(jQuery, window));
