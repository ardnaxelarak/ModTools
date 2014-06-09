CREATE OR REPLACE VIEW vote_view AS SELECT v.vid, v.rid, v.voter, v.votee, v.locked, IF(g.rooms_hidden, 1, r.weight) as weight, ((m.m_vid IS NOT NULL) AND (r.weight IS NOT NULL OR g.rooms_hidden)) AS current FROM room_votes v LEFT JOIN max_votes m ON v.vid = m.m_vid LEFT JOIN room_players r ON (v.rid = r.rid AND v.voter = r.pid) LEFT JOIN rooms rms ON v.rid = rms.rid LEFT JOIN games g ON rms.gid = g.gid;

CREATE OR REPLACE VIEW vote_tally AS SELECT v1.rid, v1.votee AS pid, MAX(v2.vid) AS last, MAX(v1.vid) AS last_old, SUM(ifnull(v2.weight,0)) AS votes from vote_view v1 LEFT JOIN current_votes v2 ON v1.vid = v2.vid GROUP BY v1.rid, v1.votee;

CREATE OR REPLACE VIEW role_times AS SELECT gid, pid, min(id) AS first, max(id) AS last FROM player_roles GROUP BY gid, pid;

CREATE OR REPLACE VIEW role_view AS SELECT rt.gid, rt.pid, pr1.role AS first, pr2.role AS last FROM role_times rt LEFT JOIN player_roles pr1 ON rt.first = pr1.id LEFT JOIN player_roles pr2 ON rt.last = pr2.id;

CREATE OR REPLACE VIEW game_view AS select g.gid, t.tid, t.short_name AS type_short, t.name AS type_long, s.sid, s.name AS status_name, s.signup, (s.rooms AND t.rooms AND NOT g.rooms_hidden) AS show_rooms, g.thread_id, g.last_scanned, g.game_index, g.name AS game_name, count(DISTINCT p.pid) AS current_players, g.max_players, g.rooms_hidden, g.roles_change FROM games g LEFT JOIN game_types t ON g.tid = t.tid LEFT JOIN statuses s ON g.status = s.sid LEFT JOIN game_players p ON p.gid = g.gid GROUP BY g.gid;
