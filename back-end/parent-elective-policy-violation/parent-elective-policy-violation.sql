DELIMITER $$
DROP PROCEDURE IF EXISTS pepve$$
CREATE PROCEDURE pepve()

BEGIN


/*
* Semester / AY-aware logic
* F/W SemesterIDs and abbreviations for current AY are available as variables 
* Switches to upcoming AY (F/W) on Summer semester
*/
DECLARE _FallSemesterID           INT;  
DECLARE _WinterSemesterID           INT;  
DECLARE _CurrentSemesterID          INT;  
DECLARE _CurrentSemesterName VARCHAR(3);  
DECLARE _WinterSemesterAbbrv VARCHAR(3);
DECLARE _FallSemesterAbbrv VARCHAR(3);
DECLARE _SemName VARCHAR(3);

-- get current SemesterID, or next SemesterID when between semesters
SET _CurrentSemesterID   = (SELECT MAX(semesterid) FROM semester 
                            WHERE NOW() BETWEEN DATE_SUB(begindate, INTERVAL 30 DAY) -- don't switch 'target' semesters until the current semester is well underway. 
                            AND DATE_ADD(enddate, INTERVAL 30 DAY));                 -- handle 'between semesters' scenarios

SET _CurrentSemesterName = (SELECT LEFT(semestername, 1) FROM semester WHERE semesterid = _CurrentSemesterID);

SET _FallSemesterID =
	CASE
    	WHEN _CurrentSemesterName = 'S' THEN _CurrentSemesterID + 1
        WHEN _CurrentSemesterName = 'F' THEN _CurrentSemesterID
        ELSE _CurrentSemesterID - 1 -- don't update until the next AY
        END;
        
SET _WinterSemesterID =
	CASE
    	WHEN _CurrentSemesterName = 'S' THEN _CurrentSemesterID + 2
        WHEN _CurrentSemesterName = 'F' THEN _CurrentSemesterID + 1
        ELSE _CurrentSemesterID
        END;
    	
SET _WinterSemesterAbbrv = (SELECT CONCAT(RIGHT(semestername, 2), LEFT(semestername, 1)) FROM semester WHERE semesterid = _WinterSemesterID);
SET _FallSemesterAbbrv = (SELECT CONCAT(RIGHT(semestername, 2), LEFT(semestername, 1)) FROM semester WHERE semesterid = _FallSemesterID);
-- for testing purposes only, to verify variables are calculated correctly at different times of the year. Uncomment next row and comment out the entire SELECT beneath it.
-- SELECT _CurrentSemesterID, _CurrentSemesterName, _WinterSemesterID, _FallSemesterID, _WinterSemesterAbbrv, _FallSemesterAbbrv;


/*
* All LAU students enrolled in ILC elective blocks, OA, Debate, and LAU Funded LEMI
*
* CLASS IDS:
* 203 - 9th Grade Block
* 204 - 10th Grade Block
* 205 - 11th Grade Block
* 206 - 12th Grade Block
* 251 - Debate I
* 439 - Debate II
* 711 - OA
* 784 - MS Debate
* 868 - LAU Funded LEMI
*/
DROP TEMPORARY TABLE IF EXISTS _all; -- ALL LAU students enrolled in ILC elective blocks, OA, Debate, or LAU Funded courses
CREATE TEMPORARY TABLE IF NOT EXISTS _all
SELECT  e.personid AS 'id', p.lastname AS 'lname', p.firstname AS 'fname', s.classid AS 'classid',
(SELECT CASE
	    WHEN s.classid IN(203,204,205,206) THEN 'ILC Block'
	    WHEN s.classid = 251 THEN 'Debate I'
	    WHEN s.classid = 439 THEN 'Debate II'
	    WHEN s.classid = 711 THEN 'OA'
	    WHEN s.classid = 784 THEN 'MS Debate'
	    WHEN s.classid = 868 THEN 'LEMI'
	    ELSE '????????' -- testing
        END) AS 'class', m.semesterid as 'sid'
	FROM person p    
	JOIN enrollment e USING (personid)        
	JOIN section s USING (sectionid)
	Join schedule h on h.sectionid = s.sectionid
	JOIN semester m USING (semesterid)
	JOIN enrollmenttostudentdebit esd USING (enrollmentid)    
	JOIN studentdebit sd USING (studentdebitid)    
	JOIN thirdpartypayerengagement tppe USING (tppengagementid)
WHERE s.classid in(251,439,711,784,868,203,204,205,206) AND e.statusid =1 AND s.semesterid in(_FallSemesterID, _WinterSemesterID) and tppe.TPPayerID = 12612

UNION

/*
* LAU Students enrolled in any "LAU Funded..." courses
* Section IDs 36515,36517,3651 are all WL IS Electives
*/
SELECT e.personid AS 'id', p.lastname AS 'lname', p.firstname AS 'fname',  s.classid AS 'classid', dee.scheduledesc AS 'class', m.semesterid AS 'sid'
	FROM enrollment e
	JOIN person p on p.personid = e.personid
	JOIN section s USING (sectionid)
	JOIN semester m ON m.semesterid=s.semesterid
	JOIN `schedule` dee ON dee.sectionid=s.sectionid 
	JOIN class c ON c.classid=s.classid
	JOIN enrollmenttostudentdebit esd USING (enrollmentid)    
	JOIN studentdebit sd USING (studentdebitid)    
	JOIN thirdpartypayerengagement tppe USING (tppengagementid)
WHERE dee.scheduledesc LIKE "%LAU Funded%" AND e.statusid = 1 AND m.semesterid IN(_FallSemesterID,_WinterSemesterID) AND s.sectionid NOT IN(36515,36517,36519) AND tppe.TPPayerID = 12612;


/*
* A table of the 'weights' of the classes
* ILC blocks count as 2
* Everything else counts as 1
*/
DROP TEMPORARY TABLE IF EXISTS _v_all; 
CREATE TEMPORARY TABLE IF NOT EXISTS _v_all
SELECT id AS 'id', lname AS 'lname', fname AS 'fname', class AS 'class' ,  IF(class='ILC BLOCK',2,1) AS 'v', sid AS 'sid'
	FROM _all
 GROUP BY id, class, sid
ORDER BY id;


/*
* RESULT 
* All students who are taking more than 3 out 
* of the 5 permitted electives in a given semester
*/
SELECT id, lname, fname, class, SUM(v), sid, IF(sid = _FallSemesterID, _FallSemesterAbbrv, _WinterSemesterAbbrv) AS 'SemAbbrv'
	FROM _v_all
GROUP BY id,sid
HAVING SUM(v) > 3
ORDER BY sid, id;


END$$
DELIMITER ;
CALL pepve();
