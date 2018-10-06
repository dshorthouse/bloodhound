/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
var Profile = (function($, window) {

  "use strict";

  var _private = {

    init: function() {
      this.activate_radios();
      this.activate_switch();
      this.activate_orcid_refresh();
    },
    activate_switch: function() {
      $('#toggle-public').change(function() {
        $.ajax({
          method: "PUT",
          url: "/profile.json",
          dataType: "json",
          data: JSON.stringify({ is_public: $(this).prop('checked') })
        }).done(function(data) {
          
        });
      });
    },
    activate_radios: function(){
      $('input.action-radio').change(function() {
          var action = $(this).attr("data-action"),
              label = $(this).parent();
          if($(this).attr("name") === "selection-all") {
              var ids = $(this).attr("data-ids");
              $.ajax({
                  method: "PUT",
                  url: "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({ ids: ids, action: action })
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
                  url: "/user-occurrence/" + id + ".json",
                  dataType: 'json',
                  data: JSON.stringify({ action: action })
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
              url: "/user-occurrence/" + id + ".json"
          }).done(function(data) {
              row.fadeOut(500, function() {
                  $(this).remove();
              });
          });
      });
    },
    activate_orcid_refresh: function(){
      $("div.orcid-refresh a").on("click", function() {
        $.ajax({
            method: "GET",
            url: "/orcid-refresh.json"
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
    init: function() {
      _private.init();
    }
  };

}(jQuery, window));
