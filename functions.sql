delimiter //

DROP FUNCTION IF EXISTS modbot_data.VoteString;
CREATE FUNCTION modbot_data.VoteString (r_id INT, p_id INT) RETURNS VARCHAR(500)
BEGIN
       SET @row := 0;

    SELECT GROUP_CONCAT(CONCAT(IF(v.current, '', '[-]'), p.username, IF(v.locked AND v.current, '*', ''), '(', v.num, ')', IF(v.current, '', '[/-]')) SEPARATOR ', ')
      INTO @votelist
      FROM (SELECT voter, votee, locked, current, @row := @row + 1 AS num
              FROM vote_view
             WHERE rid = r_id) AS v
      JOIN players AS p
        ON p.pid = v.voter
     WHERE v.votee = p_id;

    SELECT username
      INTO @name
      FROM players
     WHERE pid = p_id;
     
    SELECT TRIM(TRAILING '.' FROM (TRIM(TRAILING '0' FROM votes)))
      INTO @votes
      FROM vote_tally
     WHERE rid = r_id
       AND pid = p_id;
     
    RETURN CONCAT_WS(' - ', @name, @votes, @votelist);
END//

delimiter ;

delimiter //

DROP PROCEDURE IF EXISTS modbot_data.Vote;
CREATE PROCEDURE modbot_data.Vote (IN g_id INT, IN p_id INT, IN new_vote BOOLEAN)
BEGIN
   DECLARE numvotes INT(4);
   DECLARE numplayers INT(4);
   DECLARE roundnum INT;
   DECLARE phasenum INT;
   DECLARE prior_vote INT(1);
   DECLARE late_message TEXT;
   
    SELECT max(round_num)
      INTO roundnum
      FROM games
     WHERE gid = g_id;
     
    SELECT max(phase_num)
      INTO phasenum
      FROM games
     WHERE gid = g_id;

    SELECT count(DISTINCT pid)
      INTO numplayers
      FROM game_players
     WHERE gid = g_id;

    SELECT count(DISTINCT pid)
      INTO numvotes
      FROM binary_votes
     WHERE gid = g_id
       AND round_num = roundnum
       AND phase_num = phasenum;
       
        IF numvotes >= numplayers THEN
            SELECT CONCAT('It is too late to change your vote. Your final vote was [b]', max(v.name), '[/b]')
              INTO late_message
              FROM binary_votes b
         LEFT JOIN games g
                ON b.gid = g.gid
         LEFT JOIN vote_names v
                ON g.tid = v.tid
               AND b.vote = v.vote;
              
            INSERT
              INTO player_messages (pid, gid, message)
            VALUES (p_id, g_id, late_message);
     ELSE
            SELECT max(id)
              INTO prior_vote
              FROM binary_votes
             WHERE gid = g_id
               AND round_num = roundnum
               AND phase_num = phasenum
               AND pid = p_id;
        
                IF prior_vote IS NOT NULL THEN
            UPDATE binary_votes
               SET vote = new_vote
             WHERE id = prior_vote;
              
              ELSE INSERT
              INTO binary_votes (gid, round_num, phase_num, pid, vote)
            VALUES (g_id, roundnum, phasenum, p_id, new_vote);
               END IF;
     END IF;
END//

delimiter ;

