-- https://app.asana.com/0/1200281177330435/1200281177330460/f
DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_partner_schools_info` $$
CREATE PROCEDURE `sp_partner_schools_info`()
BEGIN

-- return a list of students in the 'current' semester not yet registered for the 'next' semester


DECLARE _TargetSemesterID           INT;  -- the semester they are not yet registered for
DECLARE _CurrentSemesterID          INT;  -- current semester to get a baseline
DECLARE _CurrentSemesterName VARCHAR(3);  -- determine whether current semester is Fall, Winter, or Summer

-- get current SemesterID, or next SemesterID when between semesters
SET _CurrentSemesterID   = (SELECT MAX(semesterid) FROM semester 
                            WHERE NOW() BETWEEN DATE_SUB(begindate, INTERVAL 30 DAY) -- don't switch 'target' semesters until the current semester is well underway. 
                            AND DATE_ADD(enddate, INTERVAL 30 DAY));                 -- handle 'between semesters' scenarios

SET _CurrentSemesterName = (SELECT LEFT(semestername, 1) FROM semester WHERE semesterid = _CurrentSemesterID);
SET _TargetSemesterID = IF(_CurrentSemesterName = 'S', _CurrentSemesterID + 1, _CurrentSemesterID); -- skip Summer semester

SELECT tpp.tppayerid, tppp.preferredname AS 'Third-Party Payer', 
tppp.state AS 'State', 
(CASE WHEN tpp.tppapproved=1 THEN 'Active' ELSE 'Not Active' END) AS 'Status', 
CONCAT(RIGHT(tppfs.Semester, 2), LEFT(tppfs.Semester, 1)) AS 'First Semester',
-- If tpp is active, display student count, otherwise display last active semester
IF(tpp.TPPApproved=1 AND
   (SELECT COUNT(DISTINCT(e.personid))
     FROM enrollment e
     JOIN section s ON s.sectionid = e.sectionid AND s.semesterid =  _TargetSemesterID
     JOIN enrollmenttostudentdebit esd USING (enrollmentid)
     JOIN studentdebit sd USING (studentdebitid)
     JOIN thirdpartypayerengagement tppe USING (tppengagementid)
     LEFT JOIN studentdebit asd ON asd.adjustsdebitid=sd.studentdebitid
 WHERE s.classid 
 		NOT IN (414,497,502,543,544,545,546,502,551) 
 		AND asd.studentdebitid IS NULL 
 		AND e.statusid IN (1,4) 
        AND tpp.tppayerid=tppe.tppayerid)!=0
   , 
(SELECT COUNT(DISTINCT(e.personid))
     FROM enrollment e
     JOIN section s ON s.sectionid = e.sectionid AND s.semesterid =  _TargetSemesterID
     JOIN enrollmenttostudentdebit esd USING (enrollmentid)
     JOIN studentdebit sd USING (studentdebitid)
     JOIN thirdpartypayerengagement tppe USING (tppengagementid)
     LEFT JOIN studentdebit asd ON asd.adjustsdebitid=sd.studentdebitid
 WHERE s.classid 
 		NOT IN (414,497,502,543,544,545,546,502,551) 
 		AND asd.studentdebitid IS NULL 
 		AND e.statusid IN (1,4) 
        AND tpp.tppayerid=tppe.tppayerid), 
 CONCAT(RIGHT(tppfs.max_s, 2), LEFT(tppfs.max_s, 1))) AS 'Last Semester',
 (SELECT COUNT(DISTINCT firstpersonid) FROM person_relation WHERE relationtype LIKE "%third%") AS 'SIS Contacts'

FROM thirdpartypayer tpp   
JOIN person tppp ON tpp.tppayerpersonid=tppp.personid 
LEFT JOIN (
    SELECT tppe.tppayerid, MIN(m.semesterid), m.semestername AS 'Semester', MAX(m.semestername) as 'Max_s'
    FROM enrollment e
    JOIN section s USING (sectionid)
    JOIN semester m USING (semesterid)
    JOIN enrollmenttostudentdebit esd USING (enrollmentid)
    JOIN studentdebit sd USING (studentdebitid)
    JOIN thirdpartypayerengagement tppe USING (tppengagementid)
    LEFT JOIN studentdebit asd ON asd.adjustsdebitid=sd.studentdebitid
    WHERE s.classid NOT IN (414,497,502,543,544,545,546,502,551) AND asd.studentdebitid IS NULL AND e.statusid IN (1,4) 
       AND sd.obsolete=0
    GROUP BY tppe.tppayerid) AS tppfs ON tppfs.tppayerid=tpp.tppayerid  
ORDER BY `Third-Party Payer`;

END $$

DELIMITER ;

CALL sp_partner_schools_info();
