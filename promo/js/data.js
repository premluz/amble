// The storyboard: copy, timing and the one day the film follows. Colours are
// not here — categories are keys into the CSS tokens (css/app.css).
(function (F) {
  const hm = (h, m = 0) => h * 60 + m;

  F.D = {
    product: 'Amble',
    fps: 30,
    duration: 64,
    poster: 17.6,
    stage: { w: 1920, h: 1080 },

    copy: {
      dawn: 'Every day starts as a plan.',
      happens: 'Then the day happens.',
      problem: ['Most planners', 'are built for', 'making a plan.'],
      promise: ['Amble is built', 'for changing one.'],
      late: 'Running late?',
      push: ['Move one thing.', 'The rest follows.'],
      zones: 'Time, with meaning.',
      zonesSub: 'Morning. Work. Evening.',
      done: 'Done feels done.',
      voice: 'Just say it.',
      tooMuch: 'Too much today?',
      matters: ['Let the rest', 'fall away.'],
      patterns: 'See what repeats.',
      patternsSub: 'No streaks. No pressure.',
      change: 'Plans change.',
      letThem: 'Let them.',
      tagline: 'Less time planning. More time living.',
    },

    // Scene windows in film seconds. Only the phone-less openers overlap;
    // phone scenes are contiguous so exactly one of them owns each frame.
    scenes: {
      dawn: [0, 6.6],
      grid: [6, 15.6],
      reveal: [15, 20],
      push: [20, 28],
      zones: [28, 33.5],
      done: [33.5, 37.5],
      voice: [37.5, 44.5],
      matters: [44.5, 50],
      patterns: [50, 54],
      close: [54, 64],
    },

    // The film is one day: [film second, minutes since midnight].
    clock: [
      [0, hm(6)], [5.6, hm(6, 40)], [6.4, hm(8, 55)], [15, hm(9, 40)],
      [20, hm(9, 42)], [27.6, hm(9, 44)], [28.4, hm(11)], [33.2, hm(11, 2)],
      [33.9, hm(11, 40)], [37.2, hm(11, 42)], [37.9, hm(13, 10)],
      [44.2, hm(13, 14)], [44.9, hm(15, 5)], [49.8, hm(15, 8)],
      [50.4, hm(18, 30)], [53.8, hm(18, 32)], [54.6, hm(21, 30)],
      [62, hm(22, 40)], [64, hm(23)],
    ],

    categories: {
      general: { icon: null, label: 'General' },
      health: { icon: 'heart', label: 'Health' },
      work: { icon: 'briefcase', label: 'Work' },
      home: { icon: 'home', label: 'Home' },
      social: { icon: 'users', label: 'Social' },
      reading: { icon: 'book', label: 'Reading' },
    },

    tasks: [
      { id: 'run', title: 'Morning run', start: hm(7), dur: 45, cat: 'health', done: true },
      { id: 'breakfast', title: 'Breakfast', start: hm(8), dur: 30, cat: 'home', done: true },
      { id: 'standup', title: 'Standup', start: hm(9), dur: 30, cat: 'work', done: true },
      { id: 'deck', title: 'Launch deck', start: hm(9, 30), dur: 90, cat: 'work', star: true },
      { id: 'ana', title: 'Call with Ana', start: hm(11), dur: 30, cat: 'social' },
      { id: 'lunch', title: 'Lunch with Sam', start: hm(11, 30), dur: 60, cat: 'general' },
      { id: 'dentist', title: 'Dentist', start: hm(13, 30), dur: 30, cat: 'health' },
      { id: 'review', title: 'Design review', start: hm(14, 30), dur: 90, cat: 'work', star: true },
      { id: 'groceries', title: 'Groceries', start: hm(16, 30), dur: 30, cat: 'home' },
      { id: 'yoga', title: 'Yoga', start: hm(18), dur: 45, cat: 'health', star: true },
      { id: 'read', title: 'Read', start: hm(19, 30), dur: 60, cat: 'reading' },
    ],

    // computeCascadeMoves for "Launch deck" dropped at 10:00 (nearest-edge push).
    cascade: { deck: hm(10), ana: hm(11, 30), lunch: hm(12) },

    zones: [
      { id: 'morning', title: 'Morning', start: hm(6, 30), end: hm(9) },
      { id: 'work', title: 'Work', start: hm(9), end: hm(17) },
      { id: 'evening', title: 'Evening', start: hm(18), end: hm(22) },
    ],

    inbox: ['Buy oat milk', 'Renew passport'],
    spoken: ['Call mom tonight', 'Book flights to Lisbon', 'Pick up dry cleaning'],

    week: 'Mon 5 Oct – Sun 11 Oct',
    // 1 = done, 2 = completes on screen during the Patterns beat.
    habits: [
      { title: 'Run', days: [1, 1, 1, 2, 0, 0, 0] },
      { title: 'Read', days: [1, 0, 1, 2, 0, 0, 0] },
      { title: 'Meditate', days: [0, 1, 1, 0, 0, 0, 0] },
    ],

    date: 'Thu 8 Oct',
  };

  F.D.hm = hm;
})((window.Film = window.Film || {}));
