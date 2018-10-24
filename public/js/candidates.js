/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
Array.prototype.unique = function() {
  return this.filter(function (value, index, self) { 
    return self.indexOf(value) === index;
  });
}

var Candidates = (function($, window) {

  "use strict";

  var _private = {
    user_id: "",
    path: "",
    data_sources: { agent : {} },

    init: function(user_id = "", path = "") {
      this.user_id = user_id;
      this.path = path;
      this.bloodhound();
      this.typeahead();
      this.activate_switch();
      this.activate_radios();
      this.activate_orcid_refresh();
    },
    bloodhound: function() {
      this.data_sources.agent = this.create_bloodhound('agent');
      this.data_sources.agent.initialize();
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
    create_bloodhound: function(type) {
      return new Bloodhound({
        datumTokenizer : Bloodhound.tokenizers.whitespace,
        queryTokenizer : Bloodhound.tokenizers.whitespace,
        sufficient : 10,
        remote : {
          url : '/'+type+'.json?q=%QUERY',
          wildcard : '%QUERY',
          transform : function(r) {
            return $.map(r, function(v) { v['type'] = type; return v; });
          }
        }
      });
    },
    typeahead: function(){
      $('#typeahead').typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: 'agent',
          source : this.data_sources.agent.ttAdapter(),
          display : 'name'
        }
        ).on('typeahead:select', function(obj, datum) {
          window.location.href = '/profile/candidates/agent/' + datum.id;
        });
    },
    activate_radios: function(){
      var self = this;
      $('input.specimen-selector').change(function() {
        var action = $(this).attr("data-action"),
            input = $(this);
        if($(this).attr("name") === "selection-all") {
            var occurrence_ids = $.map($('[data-occurrence-id]'), function(e) {
              return $(e).attr("data-occurrence-id");
            }).unique().toString();
            $.ajax({
                method: "POST",
                url: self.path + "/user-occurrence/bulk.json",
                dataType: "json",
                data: JSON.stringify({
                  user_id: self.user_id,
                  occurrence_ids: occurrence_ids,
                  action: action,
                  visible: true
                })
            }).done(function(data) {
                $('.table tbody tr').fadeOut(250, function() {
                  $(this).remove();
                  location.reload();
                });
            }); 
        } else {
          var occurrence_id = $(this).attr("data-occurrence-id");
          $.ajax({
              method: "POST",
              url: self.path + "/user-occurrence/" + occurrence_id + ".json",
              dataType: "json",
              data: JSON.stringify({
                user_id: self.user_id,
                action: action,
                visible: true
              })
          }).done(function(data) {
            input.parents("tr").fadeOut(250, function() {
              $(this).remove();
              if ($('input.specimen-selector').length === 6) {
                location.reload();
              }
            });
          });
        }
      });
      $('button.remove-all').on('click', function() {
        var occurrence_ids = $.map($('[data-occurrence-id]'), function(e) {
          return $(e).attr("data-occurrence-id");
        }).unique().toString();
        $.ajax({
            method: "POST",
            url: self.path + "/user-occurrence/bulk.json",
            dataType: "json",
            data: JSON.stringify({
              user_id: self.user_id, occurrence_ids: occurrence_ids, visible: false
            })
        }).done(function(data) {
            $('.table tbody tr').fadeOut(250, function() {
              $(this).remove();
              location.reload();
            });
        });
      });
      $('button.remove').on('click', function() {
          var occurrence_id = $(this).attr("data-occurrence-id"),
              row = $(this).parents("tr");
          $.ajax({
              method: "POST",
              url: self.path + "/user-occurrence/" + occurrence_id + ".json",
              dataType: "json",
              data: JSON.stringify({ user_id: self.user_id, visible: false})
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
    init: function(id = "", path = "") {
      _private.init(id, path);
    }
  };

}(jQuery, window));
