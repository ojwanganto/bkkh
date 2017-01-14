

-- ============================================== Patient Daily List final query to accommodate multiple primary diagnosis ===================================

select 
e.patient_id,
e.encounter_id,
date(e.encounter_datetime) as encounterDate,
pi.identifier as KH_Number,
concat_ws(' ', pn.family_name, pn.middle_name, pn.given_name) as patient_name,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
adm.Primary,
adm.Secondary,
min(date(op.value_datetime)) as DoO,
	if(min(date(op.value_datetime)) is not null, datediff(curdate(), min(date(op.value_datetime))), '') as num_days 
from encounter e 
inner join encounter_type et on et.encounter_type_id=e.encounter_type and et.uuid= 'd02513f0-8b7a-4040-9dbf-7a1eb62cc271'
inner join
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
left outer join patient_identifier pi on pi.patient_id = e.patient_id and pi.identifier_type=4 and pi.voided=0
inner join person p on p.person_id = adm.person_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join obs op on e.patient_id = op.person_id and op.concept_id =159619 and op.voided=0 and op.value_datetime >= :effectiveDate
where e.voided=0 and date(e.encounter_datetime) = :effectiveDate

-- Notes :162169
-- Appointment Date: 5096
-- Operation : 1651
-- surgeon: encounter_provider
-- =================================================================================================================================
--- crafting operations
-- Bookings encounter_id=14

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
group by e.encounter_id;

select 
o.encounter_id, 
o.value_text as notes 
from obs o 
where o.concept_id=162169 and o.voided=0
group by o.encounter_id

-- ========================================================== ALL LINKED =========================================================================

select 
e.patient_id,
e.encounter_id,
date(e.encounter_datetime) as encounterDate,
pi.identifier as KH_Number,
concat_ws(' ', pn.family_name, pn.middle_name, pn.given_name) as patient_name,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
adm.Primary,
adm.Secondary,
date(bk.Appointment_Date) as DoO,
bk.Surgeon as Surgeon,
bk.Operation as Operation,
e_notes.notes,
datediff(curdate(), min(date(bk.Appointment_Date))) as num_days 
from encounter e 
inner join encounter_type et on et.encounter_type_id=e.encounter_type and et.uuid= 'd02513f0-8b7a-4040-9dbf-7a1eb62cc271'
inner join 
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
inner join
(
select 
o.encounter_id, 
o.value_text as notes 
from obs o 
where o.concept_id=162169 and o.voided=0
group by o.encounter_id
) e_notes on e_notes.encounter_id=e.encounter_id
inner join 
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
left outer join patient_identifier pi on pi.patient_id = e.patient_id and pi.identifier_type=4 and pi.voided=0
inner join person p on p.person_id = adm.person_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
where e.voided=0 and date(e.encounter_datetime) = :effectiveDate

-- ========================================================================= BRRI FInancial Report ==========================================================

select 
	c.stay_cost,
	c.procedure_cost,
	c.anaesthesia_cost,
	c.doctor_cost,
	c.meds_cost,
	c.lab_cost,
	c.xray_cost,
	c.supplies_cost,
	c.file_cost,
	c.follow_up_cost,
	p.payment_date, 
	p.amount_paid, 
	p.nhif,
	a.account_name,
	m.mode_of_payment
from bkkh_payment p
inner join bkkh_charges c on c.charges_id = p.charges_id
inner join bkkh_mode_of_payment m on m.mode_of_payment_id = p.mode_of_payment_id
inner join bkkh_charge_account a on a.charge_account_id = p.charge_account_id


---                                       modified 

select 
khNo.value_text as KH_Number,
pn.family_name last_name,
pn.given_name first_name,
p.birthdate as dob,
p.gender as sex,
cost.*
from
(
select 
c.patient_id,
c.stay_cost,
c.procedure_cost,
c. anaesthesia_cost,
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
inner join (
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
group by charges_id) pc  on c.charges_id = pc.charges_id
inner join bkkh_charge_account a on a.charge_account_id = pc.charge_account_id
) cost
inner join person p on p.person_id=cost.patient_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join obs khNo on khNo.person_id = cost.patient_id and khNo.voided =0 and khNo.concept_id=5325
;

-- ======================================================= Joining charges to admission ============================================================

select 
pi.identifier as KH_Number,
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
inner join (
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
;


-- ====================================================== factoring in modes of payment ============================================================

mysql> select encounter_type_id, name from encounter_type;
+-------------------+----------------------------+
| encounter_type_id | name                       |
+-------------------+----------------------------+
|                 4 | Admission                  |
|                15 | Admission (BKKH)           |
|                14 | Bookings Form (BKKH)       |
|                 1 | Check In                   |
|                 6 | Check Out                  |
|                 3 | Discharge                  |
|                 9 | Discharge (BKKH)           |
|                13 | Investigations (BKKH)      |
|                11 | NeuroVisit (BKKH)          |
|                12 | Pediatric Visits (BKKH)    |
|                 8 | Procedures (BKKH)          |
|                10 | Social Form (BKKH)         |
|                16 | Surgical Procedures (BKKH) |
|                 7 | Transfer                   |
|                 5 | Visit Note                 |
|                 2 | Vitals                     |
+-------------------+----------------------------+
16 rows in set (0.00 sec)

-- ======================================== surgical procedure ================================================

Patient Name			Weight	5089	
KH #			DOB		Age
Gender					
Name of Operation	group conc: 1938. concept	1651. coded			
Date of Operation	encounter date				
Preoperative Dx		163034 coded			
Postoperative Dx		163035 coded			
Procedure		1651 coded			
Surgeon		1473			
Findings		160029			
Operative Details		160632			
Condition of patient					
Drain					
EBL		161928			
Total Fluid intake					
Blood product volume					
Total Urine Output		161929	

-- ================================================= Brief Operative Report query =======================================================

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
having DoO = :date_of_operation and khNo = :ptID


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