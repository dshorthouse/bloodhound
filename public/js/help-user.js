/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
Array.prototype.unique = function() {
  return this.filter(function (value, index, self) { 
    return self.indexOf(value) === index;
  });
}

var HelpUser = (function($, window) {

  "use strict";

  var _private = {
    user_id: "",
    data_sources: { user : {} },

    init: function(user_id = "") {
      this.user_id = user_id;
      this.bloodhound();
      this.typeahead();
      this.activate_radios();
    },
    bloodhound: function() {
      this.data_sources.user = this.create_bloodhound('user');
      this.data_sources.user.initialize();
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
          name: 'user',
          source : this.data_sources.user.ttAdapter(),
          display : 'name'
        }
        ).on('typeahead:select', function(obj, datum) {
          window.location.href = '/help-user/' + datum.orcid;
        });
    },
    activate_radios: function() {
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
                url: "/user-occurrence/bulk.json",
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
              url: "/user-occurrence/" + occurrence_id + ".json",
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
    }
  };

  return {
    init: function(id = "") {
      _private.init(id);
    }
  };

}(jQuery, window));
