// Boot: build the stage, the phone and its screens, then each scene's set.
(function (F) {
  function boot() {
    F.ui.stage.build();
    F.copy.build();
    F.ui.phone.build();
    F.dock.build();
    F.day.build();
    F.list.build();
    F.things.build();
    F.patterns.build();
    F.fx.build();
    F.buildScenes();
    F.start();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})((window.Film = window.Film || {}));
