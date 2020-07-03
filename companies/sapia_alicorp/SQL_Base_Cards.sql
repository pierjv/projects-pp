WITH tmp_mediacalrecords 
     AS (SELECT a.id_medicalrecord, 
                a.id_worker, 
                a.risk_group_status, 
                a.current_case, 
                a.alarm, 
                a.discharge, 
                a.created_at 
         FROM   (SELECT me."_id"           AS id_medicalrecord, 
                        me.id_worker, 
                        me.risk_group_status, 
                        me.current_case, 
                        me.alarm, 
                        me.discharge, 
                        Max(me.created_at) AS created_at 
                 FROM   healthcare.medicalrecords me 
                 GROUP  BY 1, 
                           2, 
                           3, 
                           4, 
                           5, 
                           6) a 
                INNER JOIN (SELECT me.id_worker, 
                                   Max(me.created_at) AS created_at 
                            FROM   healthcare.medicalrecords me 
                            GROUP  BY 1) b 
                        ON a.id_worker = b.id_worker 
                           AND a.created_at = b.created_at), 
     tmp_workers 
     AS (SELECT wo.company_sociedad, 
                Count(wo.document_number) AS TotalTrabajadores 
         FROM   stg.workers wo 
         GROUP  BY 1), 
     tmp_cuarentenas 
     AS (SELECT c.id_medicalrecord, 
                c.start_date_symptoms, 
                c.reason, 
                Max(c.created_at) AS FechaDeRegistro, 
                Max(c.start_date) AS FechaDeReporteCovid 
         FROM   healthcare.cuarentenas c 
         GROUP  BY 1, 
                   2, 
                   3), 
     tmp_atencionmedicas 
     AS (SELECT a.id_worker, 
                a.status, 
                a.fecharegistro 
         FROM   (SELECT a.id_worker, 
                        a.status, 
                        Max(a.created_at) AS FechaRegistro, 
                        Max(a."_id")      AS Id 
                 FROM   healthcare.atencionmedicas a 
                 GROUP  BY 1, 
                           2) a 
                INNER JOIN (SELECT b.id_worker, 
                                   Max(b.created_at) AS FechaRegistro, 
                                   Max(b."_id")      AS Id 
                            FROM   healthcare.atencionmedicas b 
                            GROUP  BY 1) b 
                        ON a.id_worker = b.id_worker 
                           AND a.fecharegistro = b.fecharegistro 
                           AND a.id = b.id), 
     tmp_hospitalizacions 
     AS (SELECT h.id_worker, 
                h.reason, 
                h.place, 
                h.date_end, 
                Max(h.created_at) 
         FROM   healthcare.hospitalizacions h 
         GROUP  BY 1, 
                   2, 
                   3, 
                   4), 
     tmp_hospitalizacionuci 
     AS (SELECT h.id_worker, 
                Count(h.created_at) AS Cantidad 
         FROM   healthcare.hospitalizacions h 
         WHERE  h.reason IN ( 'UCI' ) 
         GROUP  BY 1), 
     tmp_covidtests 
     AS (SELECT a.id_worker, 
                a.tipo, 
                a.resultado, 
                a.created_at 
         FROM   (SELECT co.id_worker, 
                        co."type"          AS tipo, 
                        co."result"        AS resultado, 
                        Max(co.created_at) AS created_at 
                 FROM   healthcare.covidtests co 
                 GROUP  BY 1, 
                           2, 
                           3) a 
                INNER JOIN (SELECT co.id_worker, 
                                   Max(co.created_at) AS created_at 
                            FROM   healthcare.covidtests co 
                            GROUP  BY 1) b 
                        ON a.id_worker = b.id_worker 
                           AND a.created_at = b.created_at), 
     tmp_covidtestspruebas 
     AS (SELECT CASE 
                  WHEN co."type" IN( 'PRUEBA RAPIDA', 'PRUEBA RÁPIDA', 'RAPIDA', 'RÁPIDA' ) 
                  THEN 'RAPIDA' 
                  WHEN co."type" IN( 'MOLECULAR' ) THEN 'MOLECULAR' 
                  ELSE co."type" 
                END                 AS tipo, 
                Count(co.id_worker) AS cantidad 
         FROM   healthcare.covidtests co 
         GROUP  BY 1) 
SELECT w.country_name        AS "Pais", 
       w.id				     AS "Codigo", 
       Concat(w.first_name, ' ', w.second_name, ' ', w.fathers_last_name, ' ', 
       w.mothers_last_name)  AS "NombreyApellido", 
       w.company_sociedad    AS "Sociedad", 
       w.company_planta      AS "Planta", 
       wo.totaltrabajadores  AS "TotalTrabajadores", 
       te.tipo               AS "TipoEmpleado", 
       c.fechaderegistro     AS "FechaDeRegistro", 
       c.fechadereportecovid AS "FechaDeReporteCovid", 
       a.fecharegistro       AS "FechaDeUltimoContacto", 
       CASE 
         WHEN a.status IN ('SINTOMATICO','SINTOMÁTICO') THEN a.fecharegistro + '26 day' 
         WHEN a.status IN ('ASINTOMATICO','ASINTOMÁTICO') THEN a.fecharegistro + '14 day'
         ELSE NULL 
       END                   AS "FechaDeAltaPY",
       DATE_PART('dow',  to_date(c.fechadereportecovid ,'YYYYMMDD')) 
        			         AS "SemanaDeAltaPY", 
       TO_CHAR(a.fecharegistro, 'HH24:MI:SS')                  
        			         AS "HoraUltimoContacto", 
       DATE_PART('year', CURRENT_DATE) -    
       DATE_PART('year', w.birth_date)    
       					     AS "Edad",   
       me.risk_group_status  AS "PersonaEnRiesgo", 
       CASE 
         WHEN a.status IS NULL THEN 'SINTOMATICO' 
         ELSE 'SI' 
       END                   AS "SintomaticoAsintomatico", 
       me.discharge          AS "Clase",  
       me.current_case       AS "ClasificacionDeCaso", 
       c.reason              AS "PersonasConSintomas", 
       me.alarm              AS "SigonsDeAlarma", 
       h.place               AS "EstalbecimientoDeSalud", 
       CASE 
         WHEN h.place IS NULL THEN '' 
         ELSE 'SI' 
       END                   AS "Hospitalizado", 
       CASE 
         WHEN h.place IS NULL THEN null 
         ELSE h.date_end 
       END                   AS "AltatHospitalaria", 
       CASE 
         WHEN h.place IS NULL THEN 'NO' 
         ELSE 'SI' 
       END                   AS "AltatHospitalariaD", 
       CASE 
         WHEN me.discharge IS NULL THEN me.current_case  
         ELSE me.discharge 
       END                   AS "IncidenciasUltimoContacto",   
       	CURRENT_DATE - 
       	to_date(c.start_date_symptoms,'YYYY-MM-DD')	+ 1		  
       	                     AS "NroDiasEvolucion",  --
       'Pendiente'           AS "NroDiasAsintomatico",
       CASE 
         WHEN me.discharge IS NULL THEN 'NO' 
         ELSE 'SI' 
       END                   AS "Alta",
       CASE 
         WHEN co.tipo IS NULL THEN 'NINUGUNA' 
         ELSE co.tipo 
       END                   AS "TipoPrueba",
       co.resultado          AS "Resultado", -- verificar
       CASE 
         WHEN co.resultado IS NULL THEN 'SIN PRUEBA' 
         ELSE co.resultado 
       END                   AS "IGG",
       CASE 
         WHEN co.tipo IN( 'PRUEBA RAPIDA', 'PRUEBA RÁPIDA', 'RAPIDA', 'RÁPIDA' )  
          THEN  (select cp.cantidad from tmp_covidtestspruebas cp where cp.tipo = 'RAPIDA')
         WHEN co.tipo IN ('MOLECULAR') 
          THEN ( select cp.cantidad from tmp_covidtestspruebas cp where cp.tipo = 'MOLECULAR')
         ELSE 0 
       END                   AS "TotalPruebas",    
       'Pendiente'           AS "DiasSintomatico",
       'Preguntar'           AS "DiasParaElAlta",
       CASE 
         WHEN a.status IN ('SINTOMATICO','SINTOMÁTICO') THEN 26 
         WHEN a.status IN ('ASINTOMATICO','ASINTOMÁTICO') THEN 14
         ELSE NULL                                                                                                                                                                      
       END            AS "DiasAltaPorPlanta",
       auxiliar.rangodevol(50) 
       			             AS "RangoDias",
        CASE 
          WHEN tu.id_worker IS NULL THEN NULL 
          ELSE 'UCI' 
        END                   AS "Uci"
FROM   tmp_mediacalrecords me
       LEFT JOIN healthcare.workers w 
              ON w.id = me.id_worker 
       LEFT JOIN auxiliar.tipoempleado te 
              ON te.company_area = w.company_area 
       LEFT JOIN tmp_workers wo 
              ON w.company_sociedad = wo.company_sociedad 
       LEFT JOIN tmp_cuarentenas c 
              ON me.id_medicalrecord = c.id_medicalrecord 
       LEFT JOIN tmp_atencionmedicas a 
              ON me.id_worker  = a.id_worker 
       LEFT JOIN tmp_hospitalizacions h 
              on me.id_worker  = h.id_worker
       LEFT JOIN tmp_covidtests co
              ON me.id_worker  = co.id_worker
       LEFT JOIN tmp_hospitalizacionuci tu
              ON me.id_worker  = tu.id_worker; 
             
             
           