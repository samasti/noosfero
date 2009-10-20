// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function noosfero_init() {
  // focus_first_field(); it is moving the page view when de form is down.
}

/* If applicable, find the first field in which the user can type and move the
 * keyboard focus to it.
 *
 * ToDo: focus only inside the view box to do not roll the page.
 */
function focus_first_field() {
  form = document.forms[0];
  if (form == undefined) {
    return;
  }

  for (var i = 0; i < form.elements.length; i++) {
    field = form.elements[i];
    if (field.type == 'text' || field.type == 'textarea') {
      try {
        field.focus();
        return;
      } catch(e) { }
    }
  }
}

/* * * Convert a string to a valid login name * * */
function convToValidLogin( str ) {
  return convToValidIdentifier(str, '')
}

/* * * Convert a string to a valid login name * * */
function convToValidIdentifier( str, sep ) {
  return str.toLowerCase()
            .replace( /@.*$/,     ""  )
            .replace( /á|à|ã|â/g, "a" )
            .replace( /é|ê/g,     "e" )
            .replace( /í/g,       "i" )
            .replace( /ó|ô|õ|ö/g, "o" )
            .replace( /ú|ũ|ü/g,   "u" )
            .replace( /ñ/g,       "n" )
            .replace( /ç/g,       "c" )
            .replace( /[^-_a-z0-9.]+/g, sep )
}

function updateUrlField(name_field, id) {
   url_field = $(id);
   url_field.value = convToValidIdentifier(name_field.value, "-");
   warn_value_change(url_field);
}

function show_warning(field, message) {
   new Effect.Highlight(field, {duration:3});
   $(message).show();
}

function hide_warning(field) {
   $(field).hide();
}

function enable_button(button) {
   button.enable();
   button.removeClassName("disabled");
}

function disable_button(button) {
   button.disable();
   button.addClassName("disabled");
}
