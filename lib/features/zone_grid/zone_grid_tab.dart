/// The two tabs shown at the top of the merged Edit screen — Tasks (the
/// spatial Timeline in Edit Mode) and Zones (the Weekly Zone Authoring
/// Grid). **2026-09-17 — `events` renamed to `tasks` and wired up**,
/// requested directly: "we have 2 inactive tabs on edit zone screen. We
/// need to make them work and switch edit zone with edit tasks views with
/// these tabs... one entry point instead of 2 in the header." The prior
/// `events` value was reserved in comments for a future calendar-events
/// grid, never built — confirmed directly (over adding a third segment)
/// that repurposing it now for Tasks is correct, since the events-grid
/// idea can get its own slot whenever it's actually built.
enum ZoneGridTab { tasks, zones }
