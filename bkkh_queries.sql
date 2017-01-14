
-- ====================================================================================================
-- 												BKKH Project Queries
-- ====================================================================================================

-- ============================== Patient Daily List Query =============================================


select 
e.patient_id,
e.encounter_id,
e.visit_id,
v.date_stopped,
date(e.encounter_datetime) as doa,
pi.identifier as KH_Number,
concat_ws(' ', pn.family_name, pn.middle_name, pn.given_name) as patient_name,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
adm.Primary as 'primary',
adm.Secondary as 'secondary',
date(bk.Appointment_Date) as DoO,
bk.Surgeon as Surgeon,
bk.Operation as operation,
dc.date_of_discharge,
e_notes.notes as notes,
datediff(curdate(), min(date(bk.Appointment_Date))) as num_days 
from encounter e 
inner join visit v on v.visit_id = e.visit_id and v.voided=0
inner join encounter_type et on et.encounter_type_id=e.encounter_type and et.uuid= 'd02513f0-8b7a-4040-9dbf-7a1eb62cc271'
inner join person p on p.person_id = e.patient_id and p.voided=0 and p.dead=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join patient_identifier pi on pi.patient_id = e.patient_id and pi.identifier_type=4 and pi.voided=0
left outer join 
(
select 
person_id, 
encounter_id,
group_concat( 
distinct case 
when find_in_set('Primary',y.diag)=1 then substring_index(y.diag,',',-1)
when find_in_set('Primary',y.diag)=2 then substring_index(y.diag,',',1)
else null end separator ', ') as 'Primary', 
group_concat(
distinct case 
when find_in_set('Secondary',y.diag)=1 then substring_index(y.diag,',',-1)
when find_in_set('Secondary',y.diag)=2 then substring_index(y.diag,',',1)
else null end separator ', ') as 'Secondary' 
from (
select person_id, encounter_id, group_concat(name) as diag from (
select o.obs_id,
person_id,
o.concept_id,
o.encounter_id,
o.order_id,
o.obs_group_id,
o.value_coded, 
cn.name 
from obs o
inner join encounter e on e.encounter_id = o.encounter_id and e.voided=0
inner join encounter_type et on et.encounter_type_id=e.encounter_type and et.uuid= 'd02513f0-8b7a-4040-9dbf-7a1eb62cc271' 
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en' 
where o.obs_group_id is not null and o.concept_id != 159394
order by o.obs_id desc
) x
group by x.obs_group_id
) y
group by y.encounter_id

) adm on adm.encounter_id = e.encounter_id 
left outer join
(
select 
o.encounter_id, 
o.value_text as notes 
from obs o 
where o.concept_id=162169 and o.voided=0
group by o.encounter_id
) e_notes on e_notes.encounter_id=e.encounter_id
left outer join 
(
select
e.encounter_id, 
patient_id,
concat(p.given_name,' ',p.family_name) as Surgeon,
e.encounter_datetime,
max(if(o.concept_id=5096, o.value_datetime, '')) as Appointment_Date,
max(if(o.concept_id=1651,cn.name , '')) as Operation,
e.creator
from obs o
inner join encounter e on e.encounter_id=o.encounter_id and e.voided=0
inner join person_name p on e.creator= p.person_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where o.concept_id in (5096, 1651) and e.encounter_type=14
group by e.encounter_id
) bk on bk.patient_id = e.patient_id and bk.Appointment_Date between date_add(e.encounter_datetime, interval -2 DAY) and date_add(e.encounter_datetime, interval 2 DAY)
left outer join
(
select 
patient_id, 
visit_id, 
date(encounter_datetime) as date_of_discharge 
from encounter 
where encounter_type=9
group by visit_id
) dc on dc.patient_id=e.patient_id and dc.visit_id = e.visit_id
where e.visit_id is not null and (v.date_stopped is null or dc.date_of_discharge is null) and date(e.encounter_datetime) <= :effectiveDate
group by e.patient_id, e.visit_id

-- ============================== Query changed to reflect changes to admission/hospitalization form ======================================

select 
e.patient_id,
e.encounter_id,
date(e.encounter_datetime) as doa,
pi.identifier as KH_Number,
concat_ws(' ', pn.family_name, pn.middle_name, pn.given_name) as patient_name,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
adm.Primary as 'primary',
adm.Secondary as 'secondary',
adm.dx3 as 'dx3',
date(bk.Appointment_Date) as DoO, 
bk.Surgeon as Surgeon,
bk.Operation as 'operation',
datediff(curdate(), date(bk.Appointment_Date)) as num_days,
e_notes.notes 
from encounter e 
inner join 
(
    select encounter_type, uuid,name from form where 
    uuid in('fc803dd8-aa3c-4de9-bd87-64ea7c947ae4')
) f on f.encounter_type=e.encounter_type

inner join 
(
select 
d.patient_id as person_id, 
d.encounter_id, 
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '') AS 'Primary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '') as 'Secondary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '') as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(cn.name order by obs_id separator '|') as diagnosis from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
inner join 
(
    select encounter_type, uuid,name from form where 
    uuid in('fc803dd8-aa3c-4de9-bd87-64ea7c947ae4')
) f on f.encounter_type=e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d

) adm on adm.encounter_id = e.encounter_id
left outer join
(
select 
o.encounter_id, 
o.value_text as notes 
from obs o 
where o.concept_id=162169 and o.voided=0
group by o.encounter_id
) e_notes on e_notes.encounter_id=e.encounter_id
left outer join 
(
select
e.encounter_id, 
patient_id,
concat(p.given_name,' ',p.family_name) as Surgeon,
e.encounter_datetime,
max(if(o.concept_id=5096, o.value_datetime, '')) as Appointment_Date,
max(if(o.concept_id=1651,cn.name , '')) as Operation,
e.creator
from obs o
inner join encounter e on e.encounter_id=o.encounter_id and e.voided=0
inner join person_name p on e.creator= p.person_id
inner join 
(
    select encounter_type, uuid,name from form where 
    uuid in('2f59d215-eed5-42e0-ba95-9797125b1d29')
) f on f.encounter_type=e.encounter_type
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where o.concept_id in (5096, 1651) 
group by e.encounter_id
) bk on bk.patient_id = e.patient_id and bk.Appointment_Date between date_add(e.encounter_datetime, interval -2 DAY) and date_add(e.encounter_datetime, interval 2 DAY)
left outer join patient_identifier pi on pi.patient_id = e.patient_id and pi.identifier_type=4 and pi.voided=0
inner join person p on p.person_id = adm.person_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
where e.voided=0 and date(e.encounter_datetime) = :effectiveDate



-- ===============================================================================================================================

-- ------------------------------------------------------ BKKH Financial Report --------------------------------------------------


-- ========================================================== general use =======================================

select 
pi.identifier as kh_number,
pn.family_name last_name,
pn.given_name first_name,
p.birthdate as dob,
p.gender as sex,
bk.Operation,
bk.Surgeon,
bk.Appointment_Date as DoO,
dc.date_of_discharge,
cost.*
from
(
select 
c.patient_id,
adm.Primary,
adm.Secondary,
adm.encounter_datetime as DoA,
adm.location,
adm.visit_id,
c.stay_cost,
c.procedure_cost,
c. anaesthesia_cost,
c.date_created as date_of_charge,
c.doctor_cost,
c.meds_cost,
c.lab_cost,
c.xray_cost,
c.supplies_cost,
c.file_cost,
c.follow_up_cost,  
a.account_name,
pc.*
from bkkh_charges c 
left outer join (
select
max(charges_id) as charges_id,
max(date(payment_date)) as payment_date,
charge_account_id,
max(if(mode_of_payment_id=1, amount_paid, '')) as NHIF,
max(if(mode_of_payment_id=2, amount_paid, '')) as Individual,
max(if(mode_of_payment_id=3, amount_paid, '')) as 'Government Sponsored',
max(if(mode_of_payment_id=4, amount_paid, '')) as 'NGO Sponsored',
max(if(mode_of_payment_id=5, amount_paid, '')) as 'Insurance',
max(if(mode_of_payment_id=6, amount_paid, '')) as 'Needy Fund',
sum(amount_paid) as Total_Paid
from bkkh_payment
group by charges_id
) pc  on c.charges_id = pc.charges_id
inner join 
(
select 
person_id, 
visit_id,
encounter_datetime,
location, 
encounter_id,
group_concat( 
distinct case 
when find_in_set('Primary',y.diag)=1 then substring_index(y.diag,',',-1)
when find_in_set('Primary',y.diag)=2 then substring_index(y.diag,',',1)
else null end separator ', ') as 'Primary', 
group_concat(
distinct case 
when find_in_set('Secondary',y.diag)=1 then substring_index(y.diag,',',-1)
when find_in_set('Secondary',y.diag)=2 then substring_index(y.diag,',',1)
else null end separator ', ') as 'Secondary' 
from (
select person_id, visit_id,encounter_id, encounter_datetime, location, group_concat(name) as diag from (
select o.obs_id,
person_id,
o.concept_id,
o.encounter_id,
e.encounter_datetime,
l.name as location,
e.visit_id,
o.order_id,
o.obs_group_id,
o.value_coded, 
cn.name 
from obs o
inner join encounter e on e.encounter_id = o.encounter_id and e.voided=0
inner join location l on l.location_id=e.location_id
inner join encounter_type et on et.encounter_type_id=e.encounter_type and et.uuid= 'd02513f0-8b7a-4040-9dbf-7a1eb62cc271' 
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en' 
where o.obs_group_id is not null and o.concept_id != 159394
order by o.obs_id desc
) x
group by x.obs_group_id
) y
group by y.encounter_id
) adm on adm.visit_id = c.visit_id
inner join bkkh_charge_account a on a.charge_account_id = pc.charge_account_id
) cost
left outer join
(
select
e.encounter_id, 
patient_id,
concat(p.given_name,' ',p.family_name) as Surgeon,
e.encounter_datetime,
max(if(o.concept_id=5096, o.value_datetime, '')) as Appointment_Date,
max(if(o.concept_id=1651,cn.name , '')) as Operation,
e.creator
from obs o
inner join encounter e on e.encounter_id=o.encounter_id and e.voided=0
inner join person_name p on e.creator= p.person_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where o.concept_id in (5096, 1651) and e.encounter_type=14
group by e.encounter_id
) bk on bk.patient_id = cost.patient_id and bk.Appointment_Date between date_add(cost.DoA, interval -2 DAY) and date_add(cost.DoA, interval 2 DAY)
left outer join
(
select 
patient_id, 
visit_id, 
date(encounter_datetime) as date_of_discharge 
from encounter 
where encounter_type=9
) dc on dc.patient_id=cost.patient_id and dc.visit_id = cost.visit_id
inner join person p on p.person_id=cost.patient_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join patient_identifier pi on pi.patient_id = cost.patient_id and pi.identifier_type=4 and pi.voided=0
having date_of_charge between :startDate and :endDate
;


-- ============================================ changed to hospitalization form ===========================================================

select 
pi.identifier as kh_number,
pn.family_name last_name,
pn.given_name first_name,
p.birthdate as dob,
p.gender as sex,
bk.Operation,
bk.Surgeon,
bk.Appointment_Date as DoO,
dc.date_of_discharge,
cost.*
from
(
select 
c.patient_id,
adm.Primary,
adm.Secondary,
adm.encounter_datetime as DoA,
adm.location,
adm.visit_id,
c.stay_cost,
c.procedure_cost,
c. anaesthesia_cost,
c.date_created as date_of_charge,
c.doctor_cost,
c.meds_cost,
c.lab_cost,
c.xray_cost,
c.supplies_cost,
c.file_cost,
c.follow_up_cost,  
a.account_name,
pc.*
from bkkh_charges c 
left outer join (
select
max(charges_id) as charges_id,
max(date(payment_date)) as payment_date,
charge_account_id,
max(if(mode_of_payment_id=1, amount_paid, '')) as NHIF,
max(if(mode_of_payment_id=2, amount_paid, '')) as Individual,
max(if(mode_of_payment_id=3, amount_paid, '')) as 'Government Sponsored',
max(if(mode_of_payment_id=4, amount_paid, '')) as 'NGO Sponsored',
max(if(mode_of_payment_id=5, amount_paid, '')) as 'Insurance',
max(if(mode_of_payment_id=6, amount_paid, '')) as 'Needy Fund',
sum(amount_paid) as Total_Paid
from bkkh_payment
group by charges_id
) pc  on c.charges_id = pc.charges_id
inner join (

select 
d.patient_id as person_id, 
d.encounter_id, 
d.visit_id,
d.location,
d.encounter_datetime,
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '') AS 'Primary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '') as 'Secondary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '') as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(cn.name order by obs_id separator '|') as diagnosis, e.visit_id, e.encounter_datetime, l.name as location from encounter e 
inner join location l on l.location_id=e.location_id
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
inner join 
(
    select encounter_type, uuid,name from form where 
    uuid in('fc803dd8-aa3c-4de9-bd87-64ea7c947ae4')
) f on f.encounter_type=e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d
) adm on adm.visit_id = c.visit_id
inner join bkkh_charge_account a on a.charge_account_id = pc.charge_account_id
) cost
left outer join
(
select
e.encounter_id, 
patient_id,
concat(p.given_name,' ',p.family_name) as Surgeon,
e.encounter_datetime,
max(if(o.concept_id=5096, o.value_datetime, '')) as Appointment_Date,
max(if(o.concept_id=1651,cn.name , '')) as Operation,
e.creator
from obs o
inner join encounter e on e.encounter_id=o.encounter_id and e.voided=0
inner join person_name p on e.creator= p.person_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where o.concept_id in (5096, 1651) and e.encounter_type=14
group by e.encounter_id
) bk on bk.patient_id = cost.patient_id and bk.Appointment_Date between date_add(cost.DoA, interval -2 DAY) and date_add(cost.DoA, interval 2 DAY)
left outer join
(
select 
patient_id, 
visit_id, 
date(encounter_datetime) as date_of_discharge 
from encounter 
where encounter_type=9
) dc on dc.patient_id=cost.patient_id and dc.visit_id = cost.visit_id
inner join person p on p.person_id=cost.patient_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join patient_identifier pi on pi.patient_id = cost.patient_id and pi.identifier_type=4 and pi.voided=0
having date_of_charge between :startDate and :endDate
;

-- ----------------------------------------------------------- Brief Operative Report -----------------------------------------------------

select
e.patient_id as patient,
pi.identifier as khNo,
concat_ws(' ', pn.family_name, pn.given_name) name,
p.birthdate as dob,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
p.gender as sex,
date(e.encounter_datetime) as DoO,
e.encounter_id,
max(if(o.concept_id = 1651, cn.name,'')) as operation,
max(if(o.concept_id = 163034, cn.name, '')) as dx1,
max(if(o.concept_id = 163035, cn.name, '')) as dx2,
max(if(o.concept_id = 1473, o.value_text, '')) as surgeon,
max(if(o.concept_id = 160029, cn.name, '')) as findings,
max(if(o.concept_id = 160632, o.value_text, '')) as operativeDetails,
max(if(o.concept_id = 5089, o.value_numeric, '')) as weight,
max(if(o.concept_id = 161928, o.value_numeric, '')) as ebl,
max(if(o.concept_id = 161929, o.value_numeric, '')) as urine
from obs o 
inner join encounter e on e.encounter_id = o.encounter_id and e.voided =0 
inner join person p on p.person_id=e.patient_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join patient_identifier pi on pi.patient_id = e.patient_id and pi.identifier_type=4 and pi.voided=0
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where e.encounter_type=16 
group by e.patient_id, e.encounter_id
having DoO = :date_of_operation and patient = :Patient



-- ======================================================= BRRI Statistical Report ====================================================

mysql> select encounter_type_id, name, uuid from encounter_type;
+-------------------+----------------------------+--------------------------------------+
| encounter_type_id | name                       | uuid                                 |
+-------------------+----------------------------+--------------------------------------+
|                 1 | Check In                   | ca3aed11-1aa4-42a1-b85c-8332fc8001fc |
|                 2 | Vitals                     | 67a71486-1a54-468f-ac3e-7091a9a79584 |
|                 3 | Discharge                  | 181820aa-88c9-479b-9077-af92f5364329 |
|                 4 | Admission                  | e22e39fd-7db2-45e7-80f1-60fa0d5a4378 |
|                 5 | Visit Note                 | d7151f82-c1f3-4152-a605-2f9ea7414a79 |
|                 6 | Check Out                  | 25a042b2-60bc-4940-a909-debd098b7d82 |
|                 7 | Transfer                   | 7b68d557-85ef-4fc8-b767-4fa4f5eb5c23 |
|                 8 | Procedures (BKKH)          | 39d1cf6d-be3d-45d9-b224-e6f708fbdef0 |
|                 9 | Discharge (BKKH)           | 3d2ca25a-a008-405d-a874-485d0d84c2cf |
|                10 | Social Form (BKKH)         | 3faf7df1-f57d-4661-b29e-58e2969d715f |
|                11 | NeuroVisit (BKKH)          | 4d0b20e6-9bb1-4504-bb76-24486387ca7f |
|                12 | Pediatric Visits (BKKH)    | 93c4e5dc-42ff-4512-8046-4489c9866d74 |
|                13 | Investigations (BKKH)      | b7d7740b-5767-45b6-8ae3-332476e75abf |
|                14 | Bookings Form (BKKH)       | b9490361-6c6a-446a-a6c7-ebcd766c075a |
|                15 | Hospitalization (BKKH)     | d02513f0-8b7a-4040-9dbf-7a1eb62cc271 |
|                16 | Surgical Procedures (BKKH) | f4be29e3-9713-4e3c-ad97-7136ce8768b6 |
+-------------------+----------------------------+--------------------------------------+

mysql> select form_id, name, uuid,encounter_type from form;
+---------+-----------------------------------+--------------------------------------+----------------+
| form_id | name                              | uuid                                 | encounter_type |
+---------+-----------------------------------+--------------------------------------+----------------+
|       1 | Vitals                            | a000cb34-9ec1-4344-a1c8-f692232f6edd |              2 |
|       2 | Visit Note                        | c75f120a-04ec-11e3-8780-2b40bef9a44b |              5 |
|       3 | Admission (Simple)                | d2c7532c-fb01-11e2-8ff2-fd54ab5fdb2a |              4 |
|       4 | Discharge (Simple)                | b5f8ffd8-fbde-11e2-8ff2-fd54ab5fdb2a |              3 |
|       5 | Transfer Within Hospital (Simple) | a007bbfe-fbe5-11e2-8ff2-fd54ab5fdb2a |              7 |
|       6 | Hospitalization                   | fc803dd8-aa3c-4de9-bd87-64ea7c947ae4 |             15 |
|       7 | Booking Form                      | 2f59d215-eed5-42e0-ba95-9797125b1d29 |             14 |
|       8 | Surgical Procedures               | d579417c-bdb4-4b2e-bf75-3620c7a2b27e |             16 |
|       9 | Social Form                       | 7d2a679c-bb5e-425d-b645-50ce46e29fbb |             10 |
|      10 | Neuro Visit                       | 179ea08c-f66f-4b77-80a9-a5269a75ef49 |             11 |
|      11 | PedsSurg Visit                    | 082b1c09-1237-4851-8862-4e8d0c2ecce0 |             12 |
|      12 | Bladder Investigation             | 72b1fc63-9ffc-41d3-81ba-f805a192bf54 |             13 |
|      13 | Creatinine Investigations         | 324f37a9-1b39-4a85-a8a3-26a09ef83f13 |             13 |
|      14 | CSF Investigations                | 868b87cc-3eca-4aa5-ab5a-509bc17a86ae |             13 |
|      15 | Kidney Investigation              | 2e160114-6c24-4933-bbf8-a8553e824cb9 |             13 |
|      16 | Other Investigation               | 7f4f7ccb-8992-476e-a229-0c6d63e1eda5 |             13 |
|      17 | US Head Investigation             | acb2d701-3deb-4c74-adc1-78b7dc2fce79 |             13 |
+---------+-----------------------------------+--------------------------------------+----------------+

-- filter by form
select encounter_type, uuid,name from form where 
    uuid in('72aa78e0-ee4b-47c3-9073-26f3b9ecc4a7')

-- filter by encounter 
-- -----------------------------------------------------------------------------------------
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('9d8498a4-372d-4dc4-a809-513a2434621e')
-- ==================================================   neuro visit encounter - hydrocephalus =====================================
select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 6042 and o.value_coded in (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858)

-- ================================================ neuro visit encounter spina-bifida ==============================================

select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 6042 and o.value_coded in (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353)
-- ---------------------------------------------------------------------------------------------

-- ==================================================   procedure encounter - hydrocephalus =====================================
select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 6042 and o.value_coded in (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858)

-- ================================================ neuro visit encounter spina-bifida ==============================================

select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 6042 and o.value_coded in (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353)
-- ---------------------------------------------------------------------------------------------


Hydrocephalus diagnosis concepts:115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858

Spina Bifida diagnosis Concepts: 112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353

Hydrocephalus Operations concepts: 164267,164310,164305, 164270, 164285, 164287, 164306, 164309, 164272, 164308, 164268, 164314, 164317
164312, 164286, 164295, 164270, 164262, 164262, 164291, 164284, 164273, 164303, 164281, 164277, 164318, 164313, 164265, 164293, 164261, 164285
164274, 164283, 164316, 164292, 164264, 164288, 164289, 164280, 164263, 164278, 164282, 164299, 164294, 164311, 164297, 164296, 164049, 164320

Shunt Operations total concepts: 164267,164310,164305, 164270, 164285, 164287, 164306, 164309, 164272, 164308, 164268, 164314, 164317
164312, 164286, 164295, 164270, 164262, 164262, 164291, 164284, 164273, 164303, 164281, 164277, 164318, 164313, 164265, 164293, 164261, 164285
164274, 164283, 164316, 164292, 164264, 164288, 164289, 164280, 164263, 164278, 164282, 164299, 164294, 164311, 164297, 164296

Shunt Operations revisions concepts: 164267, 164310, 164305, 164285, 164314, 164295, 164270, 164262, 164262, 
164277, 164318, 164285, 164280, 164294, 164311, 164297, 164296

ETV Operations concepts: 164049


MYELOMENINGOCELE closures?concepts: 164271, 164275, 164302, 164300, 164301, 164319, 164319
-- ----------------------------------------------- BRRI Statistical Report ----------------------------------------------------------
-- ----------------------------------------------- Hydrocephalus Only --------------------------------------------------------

-- -------------------------------------------# Children seen --------------------------------------------------------------------

SELECT person_id, encounter_date, location,
IF(dx1 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx1 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx1,
IF(dx2 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx2 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx2,
IF(dx3 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx3 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx3
FROM (
select 
d.patient_id as person_id, 
d.encounter_id, 
d.visit_id,
d.location,
date(d.encounter_datetime) as encounter_date,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '')) AS dx1,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '')) as dx2,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '')) as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(o.value_coded order by obs_id separator '|') as diagnosis, e.visit_id, e.encounter_datetime, e.location_id as location 
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d
) diagnosis
HAVING (dx1 = "Hydrocephalus" OR dx2 = "Hydrocephalus" OR dx3 = "Hydrocephalus") AND (dx1 <> "SB" AND dx2 <> "SB" AND dx3 <>"SB")


-- ------------------------------------------ # Children new in program --------------------------------------------------------------


SELECT person_id, encounter_date, location,diagnosis.encounter_id,visit_type,
IF(dx1 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx1 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx1,
IF(dx2 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx2 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx2,
IF(dx3 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx3 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx3
FROM (
select 
d.patient_id as person_id, 
d.encounter_id, 
d.visit_id,
d.location,
date(d.encounter_datetime) as encounter_date,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '')) AS dx1,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '')) as dx2,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '')) as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(o.value_coded order by obs_id separator '|') as diagnosis, e.visit_id, e.encounter_datetime, e.location_id as location 
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d
) diagnosis
inner join (
select  
e.encounter_id, 
(CASE o.value_coded WHEN 164180 THEN "Initial" WHEN 160530 THEN "Followup" ELSE "None"  END) AS visit_type
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (164181)
group by e.encounter_id) initial on initial.encounter_id = diagnosis.encounter_id
HAVING (dx1 = "Hydrocephalus" OR dx2 = "Hydrocephalus" OR dx3 = "Hydrocephalus") AND (dx1 <> "SB" AND dx2 <> "SB" AND dx3 <>"SB") and visit_type="Initial"



-- ------------------------------------------ # hydrocephalus operations ---------------------------------------------------------------
select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded, p.birthdate, 
datediff(curdate(), p.birthdate) div 365.25 as age
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('f4be29e3-9713-4e3c-ad97-7136ce8768b6')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 1651 and o.value_coded in (164267,164310,164305, 164270, 164285, 164287, 164306, 164309, 164272, 164308, 164268, 164314, 164317,
164312, 164286, 164295, 164270, 164262, 164262, 164291, 164284, 164273, 164303, 164281, 164277, 164318, 164313, 164265, 164293, 164261, 164285,
164274, 164283, 164316, 164292, 164264, 164288, 164289, 164280, 164263, 164278, 164282, 164299, 164294, 164311, 164297, 164296, 164049, 164320) 

-- -------------------------------------- --- # 1st time interventions: hydrocephalus operations ---------------------------------------------------------------------------------
-- this is not yet implemented
select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded, p.birthdate, 
datediff(curdate(), p.birthdate) div 365.25 as age
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('f4be29e3-9713-4e3c-ad97-7136ce8768b6')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 1651 and o.value_coded in (164267,164310,164305, 164270, 164285, 164287, 164306, 164309, 164272, 164308, 164268, 164314, 164317,
164312, 164286, 164295, 164270, 164262, 164262, 164291, 164284, 164273, 164303, 164281, 164277, 164318, 164313, 164265, 164293, 164261, 164285,
164274, 164283, 164316, 164292, 164264, 164288, 164289, 164280, 164263, 164278, 164282, 164299, 164294, 164311, 164297, 164296, 164049, 164320) 


-- ---------------------------------------------- # Shunt procedures (total) -------------------------------------------------------------------

select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded, p.birthdate, 
datediff(curdate(), p.birthdate) div 365.25 as age
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('f4be29e3-9713-4e3c-ad97-7136ce8768b6')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 1651 and o.value_coded in (164267,164310,164305, 164270, 164285, 164287, 164306, 164309, 164272, 164308, 164268, 164314, 164317,
164312, 164286, 164295, 164270, 164262, 164262, 164291, 164284, 164273, 164303, 164281, 164277, 164318, 164313, 164265, 164293, 164261, 164285,
164274, 164283, 164316, 164292, 164264, 164288, 164289, 164280, 164263, 164278, 164282, 164299, 164294, 164311, 164297, 164296) 


-- ---------------------------------------------- # Shunt procedures (revisions) -------------------------------------------------------------------
-- how is the overlap between revisions and total handled?

select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded, p.birthdate, 
datediff(curdate(), p.birthdate) div 365.25 as age
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('f4be29e3-9713-4e3c-ad97-7136ce8768b6')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 1651 and o.value_coded in (164267, 164310, 164305, 164285, 164314, 164295, 164270, 164262, 164262, 
164277, 164318, 164285, 164280, 164294, 164311, 164297, 164296) 


-- ---------------------------------------------- # ETV procedures  -------------------------------------------------------------------

select e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime, e.location_id, o.concept_id, o.value_coded, p.birthdate, 
datediff(curdate(), p.birthdate) div 365.25 as age
from encounter e
inner join person p on p.person_id = e.patient_id and p.voided=0
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('f4be29e3-9713-4e3c-ad97-7136ce8768b6')
) etype on etype.encounter_type_id = e.encounter_type
inner join obs o on e.encounter_id=o.encounter_id and o.concept_id = 1651 and o.value_coded =164049

-- ======================================================= spina Bifida reports =====================================================

-- -------------------------------------------# Children seen --------------------------------------------------------------------

SELECT person_id, encounter_date, location,
IF(dx1 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx1 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx1,
IF(dx2 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx2 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx2,
IF(dx3 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx3 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx3
FROM (
select 
d.patient_id as person_id, 
d.encounter_id, 
d.visit_id,
d.location,
date(d.encounter_datetime) as encounter_date,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '')) AS dx1,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '')) as dx2,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '')) as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(o.value_coded order by obs_id separator '|') as diagnosis, e.visit_id, e.encounter_datetime, e.location_id as location 
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d
) diagnosis
HAVING (dx1 = "SB" OR dx2 = "SB" OR dx3 = "SB")



-- ------------------------------------------ # Children new in program --------------------------------------------------------------


SELECT person_id, encounter_date, location,diagnosis.encounter_id,visit_type,
IF(dx1 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx1 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx1,
IF(dx2 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx2 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx2,
IF(dx3 IN (115140, 117470, 117471, 118437, 122148, 122149, 122782, 129291, 132515, 136237, 138371, 143924, 
144543, 145477, 148470, 150017, 153812, 158433, 163858), "Hydrocephalus", IF(dx3 IN (112213, 112417, 112418, 112833, 112833, 115831, 116204, 116205, 119941, 119943, 120774, 120775, 122136, 124838, 126203, 126204, 126205, 126206,
126207, 126208, 134353, 134356, 136236, 138367, 138368, 138382, 143237, 143722, 143723, 144092, 152477, 157506, 158090, 163820, 134353, 134353
),"SB", "")) AS dx3
FROM (
select 
d.patient_id as person_id, 
d.encounter_id, 
d.visit_id,
d.location,
date(d.encounter_datetime) as encounter_date,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '')) AS dx1,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '')) as dx2,
trim(IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '')) as dx3
from
(
select e.patient_id, e.encounter_id, group_concat(o.value_coded order by obs_id separator '|') as diagnosis, e.visit_id, e.encounter_datetime, e.location_id as location 
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (6042)
group by e.encounter_id
) d
) diagnosis
inner join (
select  
e.encounter_id, 
(CASE o.value_coded WHEN 164180 THEN "Initial" WHEN 160530 THEN "Followup" ELSE "None"  END) AS visit_type
from encounter e 
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
inner join (
select encounter_type_id, uuid, name from encounter_type where 
    uuid in('4d0b20e6-9bb1-4504-bb76-24486387ca7f')
) etype on etype.encounter_type_id = e.encounter_type
where o.concept_id in (164181)
group by e.encounter_id) initial on initial.encounter_id = diagnosis.encounter_id
HAVING (dx1 = "SB" OR dx2 = "SB" OR dx3 = "SB") and visit_type="Initial"




-- ===================================================== Report Descriptor ==========================================================

    {
        "id": "bkkh.reportingui.reports",
        "description": "BKKH Reports",
        "order": 10,
        "extensionPoints": [
            {
                "id": "org.openmrs.module.reportingui.reports.overview",
                "description": "Links to available Overview Reports",
                "supportedExtensionTypes": [ "link" ]
            },
            {
                "id": "org.openmrs.module.reportingui.reports.dataquality",
                "description": "Links to available Data Quality Reports",
                "supportedExtensionTypes": [ "link" ]
            },
            {
                "id": "org.openmrs.module.reportingui.reports.dataexport",
                "description": "Links to available Data Exports",
                "supportedExtensionTypes": [ "link" ]
            }
        ],
        "extensions": [
            {
                "id": "reportingui.reports.homepagelink",
                "extensionPointId": "org.openmrs.referenceapplication.homepageLink",
                "type": "link",
                "label": "reportingui.reportsapp.home.title",
                "url": "reportingui/reportsapp/home.page",
                "icon": "icon-list-alt",
                "order": 5,
                "requiredPrivilege": "App: reportingui.reports"
            },
            {
                "id": "reportingui.dataExports.adHoc",
                "extensionPointId": "org.openmrs.module.reportingui.reports.dataexport",
                "type": "link",
                "label": "reportingui.adHocAnalysis.label",
                "url": "reportingui/adHocManage.page",
                "order": 9999,
                "requiredPrivilege": "App: reportingui.adHocAnalysis",
                "featureToggle": "reportingui_adHocAnalysis"
            },
            {
                "id": "Patient Daily List Report",
                "extensionPointId": "org.openmrs.module.reportingui.reports.overview",
                "type": "link",
                "label": "Patient Daily List Report",
                "url": "reportingui/runReport.page?reportDefinition=3294a490-7fe0-4341-a270-1438603e41d3",
                "order": 1,
                "requiredPrivilege": "App: reportingui.reports"
            },
           {
                "id": "BRRI Financial Report",
                "extensionPointId": "org.openmrs.module.reportingui.reports.overview",
                "type": "link",
                "label": "BRRI Financial Report",
                "url": "reportingui/runReport.page?reportDefinition=f6aa5cdc-a48b-4e7c-84ac-7a43a0aebdba",
                "order": 1,
                "requiredPrivilege": "App: reportingui.reports"
            },
            {
                "id": "Brief Operative Report",
                "extensionPointId": "org.openmrs.module.reportingui.reports.overview",
                "type": "link",
                "label": "Brief Operative Report",
                "url": "reportingui/runReport.page?reportDefinition=762b7e66-bed2-44ea-982f-48ce4fc40935",
                "order": 1,
                "requiredPrivilege": "App: reportingui.reports"
            }
        ],
        "requiredPrivilege": "App: reportingui.reports"
    }


URLs for editing report definitions
Brief Operative Notes
- http://41.89.94.14:8080/openmrs/module/reporting/datasets/sqlDataSetEditor.form?uuid=65249821-b18a-429a-bf65-896fdc477402

BRRI Financial Report
- http://41.89.94.14:8080/openmrs/module/reporting/datasets/sqlDataSetEditor.form?uuid=df0748a7-13f4-4851-a353-c9d2a234b01f

Patient Daily List
- http://41.89.94.14:8080/openmrs/module/reporting/datasets/sqlDataSetEditor.form?uuid=f4c40476-02e0-437e-bc9f-830f4476c117




Financial Report Design : f6aa5cdc-a48b-4e7c-84ac-7a43a0aebdba

reporting/reports/reportEditor.form?uuid=f6aa5cdc-a48b-4e7c-84ac-7a43a0aebdba


					
