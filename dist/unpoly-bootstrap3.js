(function() {
  up.feedback.config.currentClasses.push('active');

  up.feedback.config.navs.push('.nav');

}).call(this);
(function() {
  up.form.config.validateTargets.unshift('.form-group:has(&)');

}).call(this);
(function() {
  up.layout.config.fixedTop.push('.navbar-fixed-top');

  up.layout.config.fixedBottom.push('.navbar-fixed-bottom');

  up.layout.config.anchoredRight.push('.navbar-fixed-top');

  up.layout.config.anchoredRight.push('.navbar-fixed-bottom');

  up.layout.config.anchoredRight.push('.footer');

}).call(this);
(function() {
  up.modal.config.template = "<div class=\"up-modal\">\n  <div class=\"up-modal-backdrop\"></div>\n  <div class=\"up-modal-viewport\">\n    <div class=\"up-modal-dialog modal-dialog\">\n      <div class=\"up-modal-content modal-content\"></div>\n    </div>\n  </div>\n</div>";

}).call(this);
(function() {


}).call(this);
