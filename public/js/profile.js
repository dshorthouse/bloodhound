/*global jQuery, window, document, self, encodeURIComponent, google, Bloodhound */
var Profile = (function($, window) {

  "use strict";

  var _private = {

    init: function() {
      this.activate_radios();
      this.activate_orcid_refresh();
    },
    activate_radios: function(){
      $('input').change(function() {
          var id = $(this).attr("data-id"),
              action = $(this).attr("data-action"),
              label = $(this).parent();
          if($(this).attr("name") === "selection-all") {
              $.ajax({
                  method: "PUT",
                  url: "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({ ids: id, action: action })
              }).done(function(data) {
                  $('label').each(function() {
                      $(this).removeClass("active");
                      if($('input:first-child', this).attr("data-action") === action) {
                          $(this).addClass("active");
                      }
                  });
              });
          } else {
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
      $("p.orcid-refresh a").on("click", function() {
        $.ajax({
            method: "GET",
            url: "/orcid-refresh.json"
        }).done(function(data) {
          $(".alert").alert().show();
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
