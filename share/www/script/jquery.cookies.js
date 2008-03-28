// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations under
// the License.

(function($) {
  $.cookies = $.cookies || {}
  $.fn.extend($.cookies, {

    /* Return the value of a cookie. */
    get: function(name) {
      var nameEq = name + "=";
      var parts = document.cookie.split(';');
      for (var i = 0; i < parts.length; i++) {
        var part = parts[i].replace(/^\s+/, "");
        if (part.indexOf(nameEq) == 0) {
          return unescape(part.substring(nameEq.length, part.length));
        }
      }
      return null;
    },

    /* Create or update a cookie. */
    set: function(name, value, days) {
      var expires = "";
      if (days) {
        var date = new Date();
        date.setTime(date.getTime() + (days * 24*60*60*1000));
        expires = "; expires=" + date.toGMTString();
      }
      document.cookie = name + "=" + escape(value) + expires;
    },

    /* Remove a cookie. */
    remove: function(name) {
      $.cookies.set(name, "", -1);
    }

  });
})(jQuery);
