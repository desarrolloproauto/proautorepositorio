USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Etl_Proauto_DWHVentas_GetVisorMepai]    Script Date: 19/1/2022 11:06:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--> 19/01/2022	-->	Se deja una unica forma de pago (recibo de caja) (RPC)

*/
ALTER procedure [dbo].[Etl_Proauto_DWHVentas_GetVisorMepai]
(
	@EMP int
)
AS

SELECT u.id,
       u.nombre,
       u.codigo_usuario
INTO #usuario
FROM dbo.usuario u
    JOIN dbo.usuario_subgrupo us
        ON us.id = u.id_usuario_subgrupo
    JOIN dbo.usuario_grupo g
        ON g.id = us.id_usuario_grupo
WHERE g.id_emp = @EMP

--- Filtro princiapl facturas solo de vehículos
SELECT t.descripcion,
       ct.id,
       ct.fecha,
       ct.id_cot_cliente,
       ct.id_cot_bodega,
       ct.numero_cotizacion,
       ct.id_veh_hn_enc,
       ct.id_usuario_vende,
       ct.id_usuario,
       hn.id_veh_hn_tipo_negocio,
       hn.fecha_estimada_entrega,
       d.id_cot_item,
       d.id_cot_item_lote,
       i.id_veh_linea_modelo,
       i.id_veh_linea,
       modeloano = i.descripcion,
       t.ecu_emision,
       anulado = CASE
                     WHEN vd.id_NC > 0 THEN
                         'SI'
                     ELSE
                         'NO'
                 END,
       lineavh = i.id_cot_item_talla,
	   ct.total_total ,
	   valor_rebate_sug=vr.valor
INTO #Documentos
FROM dbo.cot_tipo t
    JOIN dbo.cot_cotizacion ct
        ON ct.id_cot_tipo = t.id
           AND t.sw IN ( 1 )
           AND ct.id_emp = @EMP
    JOIN dbo.veh_hn_enc hn
        ON hn.id = ct.id_veh_hn_enc
    --and cast(HN.FECHA as date) between '20201201' and '20210131'
    JOIN dbo.cot_cotizacion_item d
        ON ct.id = d.id_cot_cotizacion
           AND d.id_cot_item_lote > 0
    JOIN dbo.cot_item i
        ON i.id = d.id_cot_item
    LEFT JOIN dbo.v_id_nc vd
        ON vd.id_cot_cotizacion = ct.id
	LEFT JOIN dbo.veh_rebate vr
	ON vr.id_cot_item=d.id_cot_item AND   cast(ct.fecha AS DATE) BETWEEN CAST(vr.fechaIni AS DATE) AND CAST(vr.fechaFin AS DATE)
	AND vr.id=(SELECT MAX(id) from 	veh_rebate vr2 WHERE  vr2.id_cot_item=vr.id_cot_item)


   

 --filtrar solo los datos basicos de vh para caracteristicas 
SELECT DISTINCT
       d.id,
       d.id_cot_item,
       d.id_cot_item_lote,
       d.id_veh_linea_modelo,
       d.id_veh_linea,
       d.modeloano,
       d.lineavh
INTO #Veh
FROM #Documentos d



--Caracteristicas del vh 
SELECT DISTINCT
       v.id,
       v.id_cot_item,
       v.id_cot_item_lote,
       v.id_veh_linea_modelo,
       v.id_veh_linea,
       l.vin,
       l.chasis,
       v.modeloano,
       lineamodelo = vl.descripcion,
       clase = vc.descripcion,
       marca = vm.descripcion,
       color = c.descripcion,
       l.tipo_veh,
       Ubic_veh = cbu.descripcion,
       Gestor = ISNULL(cc1.razon_social, ''),
       Placa = CASE
                   WHEN ca.fecha IS NULL THEN
                       ''
                   ELSE
                       l.placa
               END,
       v.lineavh,
       Ubicacion_Especifica = l.progresivo
INTO #Vehiculos
FROM #Veh v
    JOIN dbo.cot_item_lote l
        ON l.id = v.id_cot_item_lote
    JOIN dbo.veh_linea_modelo v1
        ON v1.id = v.id_veh_linea_modelo
    JOIN dbo.veh_linea vl
        ON vl.id = v.id_veh_linea
    JOIN dbo.veh_clase vc
        ON vc.id = vl.clase
    JOIN dbo.veh_marca vm
        ON vm.id = vl.id_veh_marca
    LEFT JOIN dbo.veh_color c
        ON c.id = l.id_veh_color
    LEFT JOIN dbo.cot_bodega_ubicacion cbu
        ON cbu.id = l.id_cot_bodega_ubicacion
    LEFT JOIN dbo.v_campos_varios cvg
        ON cvg.id_cot_item_lote = l.id
           AND cvg.id_id IS NOT NULL
    LEFT JOIN dbo.cot_cliente cc1
        ON cc1.id_cot_cliente_contacto = cvg.id_id
    LEFT JOIN dbo.veh_eventos_vin ca
        ON ca.id_cot_item_lote = l.id
           AND ca.id_veh_eventos2 = 4




---campos varios asociados  la HN
SELECT d.id,
       d.id_cot_item,
       d.id_cot_item_lote,
       id_hn = hn.id,
       hn.fecha_estimada_entrega,
       Tipo_Negocio = vtn.descripcion,
       Nomb_flota = ISNULL(vf.flota, ''),
       ChevyPlan = ISNULL(cv.campo_3, 'NO'),
       Tipo_Credito = ISNULL(cv.campo_2, ''),
       Dispositivo = ISNULL(cv.campo_5, 'NO'),
       Aseguradora = ISNULL(c.razon_social, ''),
       Estado = ISNULL(ve.campo_1, ''),
       VH_Entregado =
       (
           SELECT CONVERT(VARCHAR, MAX(CAST(va.fecha AS DATETIME)))
           FROM dbo.v_cot_auditoria va
           WHERE va.id_id = hn.id
                 AND va.accion = 'E:575'
       ),
       hn.id_veh_hn_tipo_negocio,
	         
	   estadohn=hn.estado,   --GMAH 753
	   fechaultimocambio=hn.fecha_modificacion	--GMAH 753
INTO #DatosHN_Enc
FROM #Documentos d
    JOIN dbo.veh_hn_enc hn
        ON hn.id = d.id_veh_hn_enc
    LEFT JOIN dbo.veh_hn_tipo_negocio vtn
        ON vtn.id = hn.id_veh_hn_tipo_negocio
    LEFT JOIN dbo.V_FLOTAS_VH vf
        ON vf.id_hn = hn.id
    LEFT JOIN dbo.v_campos_varios cv
        ON cv.id_veh_hn_enc = hn.id
           AND cv.id_veh_estado IS NULL
    LEFT JOIN dbo.cot_cliente_contacto cc
        ON cc.id = hn.id_cot_cliente_contacto_aseguradora
    LEFT JOIN dbo.cot_cliente c
        ON c.id_cot_cliente_contacto = cc.id
    LEFT JOIN dbo.v_campos_varios ve
        ON ve.id_veh_estado = 575
           AND ve.id_veh_hn_enc = hn.id



------------------------ ESTADO HN

SELECT d.id,
       d.id_cot_item,
       d.id_cot_item_lote,
       id_hn = d.id_veh_hn_enc,
       estado = cb.descripcion,
       ca.fecha,
       notas = ca.contenido,
       id_cot_item_cam = ca.id,
       ca.id_cot_item_cam_combo,
       ca.id_id,
       cb.fecha AS fechacombo
INTO #datosEstadoHn
FROM #Documentos d
    JOIN dbo.cot_item_cam ca
        ON ca.id_veh_hn_enc = d.id_veh_hn_enc
    LEFT JOIN dbo.cot_item_cam_combo cb
        ON cb.id = ca.id_cot_item_cam_combo
WHERE ca.id_veh_estado = 575




SELECT devh.id_cot_item_cam,
       devh.id,
       devh.id_cot_item,
       devh.id_cot_item_lote,
       devh.id_hn,
       devh.estado,
       devh.fecha,
       devh.notas,
       devh.fechacombo
INTO #datosEstadoHncartera
FROM #datosEstadoHn devh
WHERE devh.id_cot_item_cam_combo <> 1718
      AND devh.id_cot_item_cam =
      (
          SELECT MAX(c2.id)
          FROM dbo.cot_item_cam c2
          WHERE c2.id_veh_hn_enc = devh.id_hn
                AND c2.id_veh_estado = 575
                AND c2.id_cot_item_cam_combo <> 1718 ---se realiza para no tomar la autorizacion a matricula
      )






SELECT devh.id,
       devh.id_cot_item,
       devh.id_cot_item_lote,
       devh.id_hn,
       devh.estado,
       devh.fecha,
       devh.notas,
       devh.id_id
INTO #datosEstadoHnmatri
FROM #datosEstadoHn devh
WHERE devh.id_cot_item_cam_combo = 1718
      AND devh.id_cot_item_cam =
      (
          SELECT MAX(devh2.id_cot_item_cam)
          FROM #datosEstadoHn devh2
          WHERE devh.id = devh2.id
                AND devh.id_cot_item_lote = devh2.id_cot_item_lote
                AND devh.id_hn = devh2.id_hn
                AND devh.id_cot_item_cam_combo = devh2.id_cot_item_cam_combo
      )






-------------------------------------

--Datos asociados al pedido
SELECT DISTINCT
       vhe.id,
       vhe.id_cot_item,
       vhe.id_cot_item_lote,
       vhe.id_veh_hn_enc,
       Apli_rebate = CASE
                         WHEN ISNULL(va.id_rebate, 0) > 0 THEN
                             'SI'
                         ELSE
                             'NO'
                     END,
       Val_Rebate = ISNULL(va.valor_rebate, 0)
INTO #DatosHN_Ped
FROM #Documentos vhe
    JOIN dbo.veh_hn_pedidos pe
        ON pe.id_veh_hn_enc = vhe.id_veh_hn_enc
    JOIN dbo.cot_pedido p
        ON p.id = pe.id_cot_pedido
    LEFT JOIN dbo.v_veh_pedido_asignado va
        ON va.id_cot_pedido = p.id




---Accesorios relacianos al vh 2003, se concatenan en una sola linea
SELECT v.id,
       v.id_cot_item_lote,
       accesorios = STUFF(
                    (
                        SELECT '|' + ci.codigo + '-' + CAST(ci.descripcion AS VARCHAR) + '-'
                               + CAST(tt.cantidad AS VARCHAR) + '-' + CAST(tt.precio AS VARCHAR) + ' / ' [text()]
                        FROM dbo.cot_item_lote_accesorios AS tt
                            LEFT JOIN dbo.cot_item ci
                                ON ci.id = tt.id_cot_item
                        WHERE tt.id_cot_item_lote = v.id_cot_item_lote
                        FOR XML PATH('')
                    ),
                    1,
                    1,
                    ''
                         )
INTO #VehAccesorios
FROM #Veh v
    JOIN dbo.cot_item_lote_accesorios t
        ON t.id_cot_item_lote = v.id_cot_item_lote
GROUP BY v.id,
         v.id_cot_item_lote




--- Datos Asociados a las formas de pago
SELECT e.id,
       e.id_cot_item,
       e.id_cot_item_lote,
       e.id_hn,
       fhn.id_veh_tipo_pago,
       fhn.notas,
       fhn.valor,
       fhn.id_cot_recibo,
       fhn.id_cot_cotizacion,
       fhn.id_cot_cliente_contacto,
       fhn.id_usuario,
       fhn.fecha_hora,
       fhn.id_usuario_reviso,
       fhn.id_cot_notas_deb_cre,
       financiera = ISNULL(cc.nombre, ''),
       Saldo_Finan = vs.saldo
INTO #DatosHN_Formap
FROM #DatosHN_Enc e
    JOIN dbo.veh_hn_forma_pago fhn
        ON fhn.id_veh_hn_enc = e.id_hn
    LEFT JOIN dbo.cot_cliente_contacto cc
        ON cc.id = fhn.id_cot_cliente_contacto
    LEFT JOIN dbo.v_cot_factura_saldo vs
        ON vs.id_cot_cotizacion = e.id
           AND fhn.id_veh_tipo_pago IN ( 3 )





----- evaluar estado de factura forma de pago credito , doc financiera
SELECT DISTINCT
       fp.id,
       fp.id_cot_item_lote,
       fp.id_hn,
       fp.id_cot_cliente_contacto,
       Valor = fp.valor,
       valor_fac = a.total_total,
       Saldo_Finan = vs.saldo
INTO #DatosHN_Formap_finan
FROM #DatosHN_Formap fp
    JOIN dbo.cot_cotizacion a
        ON a.id_veh_hn_enc = fp.id_hn
           AND a.id_cot_cliente_contacto = fp.id_cot_cliente_contacto
    LEFT JOIN dbo.v_cot_factura_saldo vs
        ON vs.id_cot_cotizacion = a.id
WHERE fp.id_veh_tipo_pago IN ( 3 )


--Resumen formas de pago
SELECT e.id,
       e.id_cot_item,
       e.id_cot_item_lote,
       Forma_Pago = CASE
                        WHEN
                        (
                            SELECT ISNULL(MAX(fhn.id), '')
                            FROM #DatosHN_Formap fhn
                            WHERE fhn.id_veh_tipo_pago IN ( 3 )
                                  AND fhn.id_hn = e.id_hn
                        ) = '' THEN
                            'Contado'
                        ELSE
                            'Crédito'
                    END,
       Financiera = MAX(e.financiera),
       Fec_Apro_fi = MAX(   CASE
                                WHEN e.id_veh_tipo_pago IN ( 3 ) THEN
                                    e.fecha_hora
                                ELSE
                                    NULL
                            END
                        ),
	
       /*Valor_anti = SUM(   CASE
                               WHEN e.id_veh_tipo_pago IN ( 1, 7, 10 ) THEN
                                   e.valor
                               ELSE
                                   0
                           END
                       ),*/
	   -- RPC --> Se deja una unica forma de pago (recibo de caja)
       Valor_anti = SUM(   CASE
                               WHEN e.id_veh_tipo_pago = 1 THEN
                                   e.valor
                               ELSE
                                   0
                           END
                       ),
	   Valor_fin = SUM(   CASE
                              WHEN e.id_veh_tipo_pago IN ( 3 ) THEN
                                  e.valor
                              ELSE
                                  0
                          END
                      ),
       Valor_NotaCredito = SUM(   CASE
                                      WHEN e.id_veh_tipo_pago IN ( 5 ) THEN
                                          e.valor
                                      ELSE
                                          0
                                  END
                              ),
       Valor_Vh_US = SUM(   CASE
                                WHEN e.id_veh_tipo_pago IN ( 2, 6 ) THEN
                                    e.valor
                                ELSE
                                    0
                            END
                        ),
       Saldo_Finan = SUM(   CASE
                                WHEN e.id_veh_tipo_pago IN ( 3 )
                                     AND e.id_cot_cotizacion IS NULL THEN
                                    e.valor
                                WHEN e.id_veh_tipo_pago IN ( 3 )
                                     AND e.id_cot_cotizacion IS NOT NULL THEN
                                    ISNULL(b.Saldo_Finan, b.valor_fac)
                            END
                        ),
       valor_CreditoCon = MAX(   CASE
                                     WHEN e.id_veh_tipo_pago IN ( 8 ) THEN
                                         e.valor
                                     ELSE
                                         NULL
                                 END
                             )
INTO #DatosHN_Formapresumen
FROM #DatosHN_Formap e
    LEFT JOIN #DatosHN_Formap_finan b
        ON b.id = e.id
           AND b.id_cot_item_lote = b.id_cot_item_lote
GROUP BY e.id,
         e.id_cot_item,
         e.id_cot_item_lote,
         e.id_hn


----Datos sobre cuotas del pedido (Credito Directo)
SELECT vhe.id,
       vhe.id_cot_item,
       vhe.id_cot_item_lote,
       vhe.id_veh_hn_enc,
       Valor_CD = CAST(SUM(ISNULL(cc.valor_cuota, 0)) AS DECIMAL(18, 2))
INTO #DatosHN_CD
FROM #Documentos vhe
    JOIN dbo.veh_hn_pedidos hv
        ON hv.id_veh_hn_enc = vhe.id_veh_hn_enc
    LEFT JOIN dbo.cot_pedido_cuotas cc
        ON cc.id_cot_pedido = hv.id_cot_pedido
GROUP BY vhe.id,
         vhe.id_cot_item,
         vhe.id_cot_item_lote,
         vhe.id_veh_hn_enc



--Datos campos varios Asocidos a la HN
--Se tiene funcion para encontra los dias no laborales (Sabado,Domingo) entre las dos fechas y restarlos
SELECT vhe.id,
       vhe.id_cot_item,
       vhe.id_cot_item_lote,
       vhe.id_veh_hn_enc,
       FechaFactura = MAX(vhe.fecha),
       Fecha_docs = MAX(   CASE
                               WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                   CAST(ca.fecha AS DATE)
                               ELSE
                                   NULL
                           END
                       ),
       Fec_Notaria = MAX(   CASE
                                WHEN cb.descripcion LIKE '%ENVIO A NOTARIA%' THEN
                                    CAST(ca.fecha AS DATE)
                                ELSE
                                    NULL
                            END
                        ),
       Fecha_Fir_cont = MAX(   CASE
                                   WHEN cb.descripcion LIKE '%DOCUMENTOS LEGALIZADOS%' THEN
                                       CAST(ca.fecha AS DATE)
                                   ELSE
                                       NULL
                               END
                           ),
       Dias_facts = DATEDIFF(
                                DAY,
                                MAX(vhe.fecha),
                                ISNULL(MAX(   CASE
                                                  WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                      ca.fecha
                                                  ELSE
                                                      NULL
                                              END
                                          ),
                                       CAST(GETDATE() AS DATE)
                                      )
                            )
                    - ISNULL(
                                dbo.fn_dias_nolaborales(
                                                           MAX(CAST(vhe.fecha AS DATE)),
                                                           ISNULL(
                                                                     MAX(   CASE
                                                                                WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                                                    CAST(ca.fecha AS DATE)
                                                                                ELSE
                                                                                    NULL
                                                                            END
                                                                        ),
                                                                     CAST(GETDATE() AS DATE)
                                                                 )
                                                       ),
                                0
                            ),
       Dias_Env_not = DATEDIFF(
                                  DAY,
                                  MAX(   CASE
                                             WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                 CAST(ca.fecha AS DATE)
                                             ELSE
                                                 NULL
                                         END
                                     ),
                                  ISNULL(MAX(   CASE
                                                    WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                        CAST(ca.fecha AS DATE)
                                                    ELSE
                                                        NULL
                                                END
                                            ),
                                         CAST(GETDATE() AS DATE)
                                        )
                              )
                      - ISNULL(
                                  dbo.fn_dias_nolaborales(
                                                             MAX(   CASE
                                                                        WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                                            CAST(ca.fecha AS DATE)
                                                                        ELSE
                                                                            NULL
                                                                    END
                                                                ),
                                                             ISNULL(
                                                                       MAX(   CASE
                                                                                  WHEN cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%' THEN
                                                                                      CAST(ca.fecha AS DATE)
                                                                                  ELSE
                                                                                      NULL
                                                                              END
                                                                          ),
                                                                       CAST(GETDATE() AS DATE)
                                                                   )
                                                         ),
                                  0
                              ),
       Dias_firm_cont = ISNULL(DATEDIFF(DAY,
                                        MAX(   CASE
                                                   WHEN cb.descripcion LIKE '%DOCUMENTOS LEGALIZADOS%' THEN
                                                       CAST(ca.fecha AS DATE)
                                                   ELSE
                                                       NULL
                                               END
                                           ),
                                        CAST(GETDATE() AS DATE)
                                       ),
                               0
                              )
                        - ISNULL(
                                    dbo.fn_dias_nolaborales(
                                                               MAX(   CASE
                                                                          WHEN cb.descripcion LIKE '%DOCUMENTOS LEGALIZADOS%' THEN
                                                                              CAST(ca.fecha AS DATE)
                                                                          ELSE
                                                                              NULL
                                                                      END
                                                                  ),
                                                               CAST(GETDATE() AS DATE)
                                                           ),
                                    0
                                )
INTO #DatosDocs_fechas
FROM #Documentos vhe
    LEFT JOIN dbo.cot_item_cam ca
        ON ca.id_veh_hn_enc = vhe.id_veh_hn_enc
    LEFT JOIN dbo.cot_item_cam_combo cb
        ON cb.id = ca.id_cot_item_cam_combo
           AND
           (
               cb.descripcion LIKE '%DOCUMENTOS FIRMADOS%'
               OR cb.descripcion LIKE '%ENVIO A NOTARIA%'
               OR cb.descripcion LIKE '%DOCUMENTOS LEGALIZADOS%'
           )
GROUP BY vhe.id,
         vhe.id_cot_item,
         vhe.id_cot_item_lote,
         vhe.id_veh_hn_enc



---Datos de Eventos relacionados ala HN
SELECT v.id,
       v.id_cot_item_lote,
       Entrega_Logis = CASE
                           WHEN ca.id_veh_eventos2 = 8 THEN
                               CAST(ca.fecha AS DATE)
                           ELSE
                               NULL
                       END,
       Dis_Solinstalacion = CASE
                                WHEN ca.id_veh_eventos2 = 5 THEN
                                    v2.descripcion
                                ELSE
                                    NULL
                            END,
       Dis_instalado = CASE
                           WHEN ca.id_veh_eventos2 = 6 THEN
                               v2.descripcion
                           ELSE
                               NULL
                       END,
       Envio_Matricula = CASE
                             WHEN ca.id_veh_eventos2 = 3 THEN
                                 CAST(ca.fecha AS DATE)
                             ELSE
                                 NULL
                         END,
       Matriculado = CASE
                         WHEN ca.id_veh_eventos2 = 4 THEN
                             CAST(ca.fecha AS DATE)
                         ELSE
                             NULL
                     END,
       Acceso_externa = CASE
                            WHEN ca.id_veh_eventos2 = 7 THEN
                                CAST(ca.fecha AS DATE)
                            ELSE
                                NULL
                        END,
       fecha_ent_acc_ext = CASE
                               WHEN ca.id_veh_eventos2 = 7 THEN
                                   CAST(ca.fecha_modifica AS DATE)
                               ELSE
                                   NULL
                           END,
       fecha_instal_dispo = CASE
                                WHEN ca.id_veh_eventos2 = 6 THEN
                                    CAST(ca.fecha AS DATE)
                                ELSE
                                    NULL
                            END,
       notas_acces_externa = CASE
                                 WHEN ca.id_veh_eventos2 = 7 THEN
                                     ISNULL(ca.notas, '')
                                 ELSE
                                     NULL
                             END,
       Recibido_Logistica = CASE
                                WHEN ca.id_veh_eventos2 = 12 THEN
                                    CAST(ca.fecha AS DATE)
                                ELSE
                                    NULL
                            END
INTO #Veheventos
FROM #Veh v
    LEFT JOIN dbo.veh_eventos_vin ca
        ON ca.id_cot_item_lote = v.id_cot_item_lote
    LEFT JOIN dbo.veh_eventos2 v2
        ON v2.id = ca.id_veh_eventos2





--Resumen de Eventos relacionados ala HN
SELECT v.id,
       v.id_cot_item_lote,
       Entrega_Logis = MAX(v.Entrega_Logis),
       Dis_Solinstalacion = MAX(v.Dis_Solinstalacion),
       Dis_instalado = MAX(v.Dis_instalado),
       Envio_Matricula = MAX(v.Envio_Matricula),
       Matriculado = MAX(v.Matriculado),
       EstadoDispositivo = ISNULL(ISNULL(MAX(v.Dis_instalado), MAX(v.Dis_Solinstalacion)), 'NO'),
       Acceso_externa = MAX(v.Acceso_externa),
       fecha_ent_acc_ext = MAX(v.fecha_ent_acc_ext),
       fecha_instal_dispo = MAX(v.fecha_instal_dispo),
       notas_acces_externa = MAX(v.notas_acces_externa),
       Recibido_Logistica = MAX(v.Recibido_Logistica)
INTO #Veheventosresumen
FROM #Veheventos v
GROUP BY v.id,
         v.id_cot_item_lote


--Datos Notas Adicionales a la HN, detalle
SELECT vhe.id,
       vhe.id_cot_item_lote,
       nota_especifica = d.nota,
       desc_tipo = n1.descripcion,
       oblig_tipo = CAST(n1.obligatoria AS BIT),
       desc_en_manos_de = n2.descripcion,
       oblig_en_manos_de = CAST(n2.obligatoria AS BIT),
       u.codigo_usuario,
       d.fecha,
       id_notas_det = n1.id
INTO #ExcepcionesNovedadEvento
FROM #Documentos vhe
    JOIN dbo.veh_hn_enc e
        ON e.id = vhe.id_veh_hn_enc
    JOIN dbo.veh_hn_notas_det d
        ON vhe.id_veh_hn_enc = d.id_veh_hn_enc
    JOIN dbo.veh_hn_notas n1
        ON n1.id = d.id_veh_hn_notas1
    JOIN dbo.veh_hn_notas n2
        ON n2.id = d.id_veh_hn_notas2
    JOIN dbo.#usuario u
        ON u.id = e.id_usuario



--Resumen y concatenacion de Notas asociadas a la HN
SELECT vhe.id,
       vhe.id_cot_item_lote,
       desc_en_manos_de = MAX(vhe.desc_en_manos_de),
       Fec_pro_regula = MAX(vhe.fecha),
       Excepciones = STUFF(
                     (
                         SELECT '| Nota:' + tt.nota_especifica + ' - En_manos_de:' + tt.desc_en_manos_de + '- Usuario:'
                                + tt.codigo_usuario + ' - Fecha: ' + CAST(CAST(tt.fecha AS DATE) AS VARCHAR) + '  ' [text()]
                         FROM #ExcepcionesNovedadEvento tt
                         WHERE tt.id_cot_item_lote = vhe.id_cot_item_lote
                               AND tt.id = vhe.id
                               AND tt.id_notas_det = 16
                         FOR XML PATH('')
                     ),
                     1,
                     1,
                     ''
                          ),
       NovedadEvento = STUFF(
                       (
                           SELECT '| Nota:' + tt.nota_especifica + ' - En_manos_de:' + tt.desc_en_manos_de
                                  + '- Usuario:' + tt.codigo_usuario + ' - Fecha: '
                                  + CAST(CAST(tt.fecha AS DATE) AS VARCHAR) + '  ' [text()]
                           FROM #ExcepcionesNovedadEvento tt
                           WHERE tt.id_cot_item_lote = vhe.id_cot_item_lote
                                 AND tt.id = vhe.id
                                 AND tt.id_notas_det NOT IN ( 16, 19 )
                           FOR XML PATH('')
                       ),
                       1,
                       1,
                       ''
                            ),
       Accesorio_de_Cliente = STUFF(
                              (
                                  SELECT '| Nota:' + tt.nota_especifica + ' - En_manos_de:' + tt.desc_en_manos_de
                                         + '- Usuario:' + tt.codigo_usuario + ' - Fecha: '
                                         + CAST(CAST(tt.fecha AS DATE) AS VARCHAR) + '  ' [text()]
                                  FROM #ExcepcionesNovedadEvento tt
                                  WHERE tt.id_cot_item_lote = vhe.id_cot_item_lote
                                        AND tt.id = vhe.id
                                        AND tt.id_notas_det IN ( 19 )
                                  FOR XML PATH('')
                              ),
                              1,
                              1,
                              ''
                                   )
INTO #ExcepcionesNovedadEvento_res
FROM #ExcepcionesNovedadEvento vhe
GROUP BY vhe.id,
         vhe.id_cot_item_lote


--Datos de contro documental.,se excluyen los que en las notas tengan OK o NA

--SELECT
--vhe.id,
--vhe.id_cot_item_lote,
--vhe.id_veh_hn_enc ,
--documento = d.descripcion,
--fecha = CAST(r.fecha AS DATE),
--hora = CONVERT(CHAR(5), r.fecha, 108),
--usuario = u.nombre,
--notas = r.notas
--into #docPendientes
--from   #Documentos vhe
--JOIN dbo.veh_hn_tipo_negocio n ON n.id = vhe.id_veh_hn_enc 
--JOIN dbo.veh_hn_tipo_documento d ON d.id_vh_tipo_negocio = n.id
--JOIN dbo.veh_hn_tipo_negocio_registro r ON r.id_veh_hn_tipo_documento = d.id AND r.id_veh_hn_enc = vhe.id_veh_hn_enc 
--JOIN dbo.#usuario u ON u.id = r.id_usuario
--WHERE LTRIM(RTRIM(r.notas)) not in ('OK','NA')


SELECT dhn.id,
       dhn.id_cot_item,
       dhn.id_cot_item_lote,
       id_veh_hn_enc = dhn.id_hn,
       id_doc = r.id_veh_hn_tipo_documento,
       documento = d.descripcion,
       fecha = CAST(r.fecha AS DATE),
       hora = CONVERT(CHAR(5), r.fecha, 108),
       usuario = u.nombre,
       notas = r.notas
INTO #docPendientes
FROM #DatosHN_Enc dhn
    JOIN dbo.veh_hn_enc enc
        ON dhn.id_hn = enc.id
    JOIN dbo.veh_hn_tipo_negocio n
        ON n.id = enc.id_veh_hn_tipo_negocio
    JOIN dbo.veh_hn_tipo_documento d
        ON d.id_vh_tipo_negocio = n.id
    JOIN dbo.veh_hn_tipo_negocio_registro r
        ON r.id_veh_hn_tipo_documento = d.id
           AND r.id_veh_hn_enc = enc.id
    JOIN dbo.usuario u
        ON u.id = r.id_usuario
WHERE enc.id_emp = @EMP
      AND
      (
          r.notas NOT LIKE '%OK%'
          AND r.notas NOT LIKE '%NA%'
      )





---Concatenacion de los documentos pendientes asociados a la HN
SELECT vhe.id,
       vhe.id_cot_item_lote,
       Documentos_pendientes = STUFF(
                               (
                                   SELECT ' | ' + tt.documento + ' - ' + ISNULL(tt.notas, '') + '  ' [text()]
                                   FROM #docPendientes tt
                                   WHERE tt.id_cot_item_lote = vhe.id_cot_item_lote
                                         AND tt.id = vhe.id
                                   FOR XML PATH('')
                               ),
                               1,
                               1,
                               ''
                                    )
INTO #docPendientes_res
FROM #docPendientes vhe
GROUP BY vhe.id,
         vhe.id_cot_item_lote



---Datos citas 
/*
id 	tipo
1	01 CITA
2	WALKIN
3	07 CITA ENTREGA VH NUEVO
7	02 CITA ACCESORIOS-PDI
8	03 CITA KIT MANDATORIOS-ACCESORIOS-PDI
9	04 CITA ACCESORIOS
10	05 CITA KIT MANDATORIOS - COMPLEMENTOS
11	06 CITA PDI
12	08 AFTER MARKET
  */

SELECT id_cot_cotizacionfac = v.id,
       id_tipo_cita = t.id,
       t.descripcion,
       tc.id,
       tc.id_cot_bodega,
       tc.id_cot_item_lote,
       tc.fecha_creacion,
       tc.fecha_cita,
       tc.notas,
       tc.id_cot_cotizacion,
       tc.estado,
       --desestadocita=isnull(ve.descripcion,case when cast(tc.fecha_cita as date)<cast(getdate()as date) then 'Atrasada' else   'agendada' end),
       desestadocita = CAST(CASE
                                WHEN tc.id_cot_item_lote IS NULL
                                     AND tc.placa IS NULL THEN
                                    NULL
                                WHEN te.id IS NOT NULL THEN
                                    'Entregada'   --8
                                WHEN ISNULL(ct.anulada, 0) = 1
                                     AND tip.sw = 46 THEN
                                    'Facturada'   --7
                                WHEN ISNULL(ct.anulada, 0) = 2 THEN
                                    'Cerrada'     --6
                                WHEN e.cuantas > 0
                                     AND e.terminada >= e.cuantas THEN
                                    'Terminada'   --5
                                WHEN e.cuantas > 0
                                     AND e.pausa >= e.cuantas THEN
                                    'Pausada'     --4 
                                WHEN e.proceso > 0 THEN
                                    'Proceso'     --3 
                                WHEN tc.id_cot_cotizacion IS NOT NULL THEN
                                    'En OT'       --2 
                                WHEN tc.estado = 101 THEN
                                    'Llegó'       --101 
                                WHEN tc.estado = 102 THEN
                                    'No cumplida' --102 
                                WHEN tc.id_cot_cotizacion IS NULL
                                     AND GETDATE() <= tc.fecha_cita THEN
                                    'Agendada'    --1 Agendada
                                WHEN tc.id_cot_cotizacion IS NULL
                                     AND GETDATE() > tc.fecha_cita THEN
                                    'Atrasada'    --100 
                            END AS VARCHAR),
       bahia = u.nombre
INTO #VehCitasPDIEntrega
FROM #Veh v
    JOIN dbo.tal_citas tc
        ON tc.id_cot_item_lote = v.id_cot_item_lote
    JOIN dbo.tal_citas_tipo t
        ON t.id = tc.id_tal_citas_tipo
    JOIN dbo.usuario u
        ON u.id = tc.id_usuario
    LEFT JOIN dbo.v_tal_citas_estado ve
        ON ve.id = tc.estado
    LEFT JOIN dbo.cot_cotizacion ct
        ON ct.id = tc.id_cot_cotizacion
    LEFT JOIN dbo.cot_tipo tip
        ON tip.id = ct.id_cot_tipo
           AND tip.sw IN ( 46 )
    LEFT JOIN dbo.v_tal_operaciones_estado e
        ON e.id_cot_cotizacion = ct.id
    LEFT JOIN dbo.tra_cargue_enc te
        ON te.id_cot_cotizacion = tc.id_cot_cotizacion
--where t.id in (7,3)
WHERE t.id IN ( 3, 7, 8, 9, 10, 11, 12 )



--AND isnull(TC.estado,0)<>102 --Pentiende por confirmar 102=citas no cumplidas



--Separar Cita por cada caso, PDI,Kitman,Accesorización adicional,AfterMarker
SELECT c.id_cot_cotizacionfac,
       c.id_cot_item_lote,
       [PDI_Fecha de cita] = MAX(   CASE
                                        WHEN (
                                                 c.id_cot_cotizacion IS NULL
                                                 AND c.id_tipo_cita IN ( 7, 8, 11 )
                                             )
                                             OR c.es_pdi = 1 THEN
                                            c.fecha_cita
                                        ELSE
                                            NULL
                                    END
                                ),
       [PDI_Nro. Cita] = MAX(   CASE
                                    WHEN (
                                             c.id_cot_cotizacion IS NULL
                                             AND c.id_tipo_cita IN ( 7, 8, 11 )
                                         )
                                         OR c.es_pdi = 1 THEN
                                        c.id
                                    ELSE
                                        NULL
                                END
                            ),
       [PDI_Notas Cita] = MAX(   CASE
                                     WHEN (
                                              c.id_cot_cotizacion IS NULL
                                              AND c.id_tipo_cita IN ( 7, 8, 11 )
                                          )
                                          OR c.es_pdi = 1 THEN
                                         CAST(c.notas AS VARCHAR(500))
                                     ELSE
                                         NULL
                                 END
                             ),
       [PDI_Bahía ] = MAX(   CASE
                                 WHEN (
                                          c.id_cot_cotizacion IS NULL
                                          AND c.id_tipo_cita IN ( 7, 8, 11 )
                                      )
                                      OR c.es_pdi = 1 THEN
                                     c.bahia
                                 ELSE
                                     NULL
                             END
                         ),
       [PDI_Estado] = MAX(   CASE
                                 WHEN (
                                          c.id_cot_cotizacion IS NULL
                                          AND c.id_tipo_cita IN ( 7, 8, 11 )
                                      )
                                      OR c.es_pdi = 1 THEN
                                     c.Estado
                                 ELSE
                                     NULL
                             END
                         ),
       [PDI_Notas Orden] = MAX(   CASE
                                      WHEN (
                                               c.id_cot_cotizacion IS NULL
                                               AND c.id_tipo_cita IN ( 7, 8, 11 )
                                           )
                                           OR c.es_pdi = 1 THEN
                                          CAST(c.Notas_orden AS VARCHAR(500))
                                      ELSE
                                          NULL
                                  END
                              ),
       [KITMAN_Fecha de cita] = MAX(   CASE
                                           WHEN (
                                                    c.id_cot_cotizacion IS NULL
                                                    AND c.id_tipo_cita IN ( 8, 10 )
                                                )
                                                OR c.es_kitoblogatorio = 1 THEN
                                               c.fecha_cita
                                           ELSE
                                               NULL
                                       END
                                   ),
       [KITMAN_Nro. Cita] = MAX(   CASE
                                       WHEN (
                                                c.id_cot_cotizacion IS NULL
                                                AND c.id_tipo_cita IN ( 8, 10 )
                                            )
                                            OR c.es_kitoblogatorio = 1 THEN
                                           c.id
                                       ELSE
                                           NULL
                                   END
                               ),
       [KITMAN_Notas Cita] = MAX(   CASE
                                        WHEN (
                                                 c.id_cot_cotizacion IS NULL
                                                 AND c.id_tipo_cita IN ( 8, 10 )
                                             )
                                             OR c.es_kitoblogatorio = 1 THEN
                                            CAST(c.notas AS VARCHAR(500))
                                        ELSE
                                            NULL
                                    END
                                ),
       [KITMAN_Bahía ] = MAX(   CASE
                                    WHEN (
                                             c.id_cot_cotizacion IS NULL
                                             AND c.id_tipo_cita IN ( 8, 10 )
                                         )
                                         OR c.es_kitoblogatorio = 1 THEN
                                        c.bahia
                                    ELSE
                                        NULL
                                END
                            ),
       [KITMAN_Estado] = MAX(   CASE
                                    WHEN (
                                             c.id_cot_cotizacion IS NULL
                                             AND c.id_tipo_cita IN ( 8, 10 )
                                         )
                                         OR c.es_kitoblogatorio = 1 THEN
                                        c.Estado
                                    ELSE
                                        NULL
                                END
                            ),
       [KITMAN_Notas Orden] = MAX(   CASE
                                         WHEN (
                                                  c.id_cot_cotizacion IS NULL
                                                  AND c.id_tipo_cita IN ( 8, 10 )
                                              )
                                              OR c.es_kitoblogatorio = 1 THEN
                                             CAST(c.Notas_orden AS VARCHAR(500))
                                         ELSE
                                             NULL
                                     END
                                 ),
       [ACCES_Fecha de cita] = MAX(   CASE
                                          WHEN (
                                                   c.id_cot_cotizacion IS NULL
                                                   AND c.id_tipo_cita IN ( 7, 8, 9 )
                                               )
                                               OR c.es_inns_acc = 1 THEN
                                              c.fecha_cita
                                          ELSE
                                              NULL
                                      END
                                  ),
       [ACCES_Nro. Cita] = MAX(   CASE
                                      WHEN (
                                               c.id_cot_cotizacion IS NULL
                                               AND c.id_tipo_cita IN ( 7, 8, 9 )
                                           )
                                           OR c.es_inns_acc = 1 THEN
                                          c.id
                                      ELSE
                                          NULL
                                  END
                              ),
       [ACCES_Notas Cita] = MAX(   CASE
                                       WHEN (
                                                c.id_cot_cotizacion IS NULL
                                                AND c.id_tipo_cita IN ( 7, 8, 9 )
                                            )
                                            OR c.es_inns_acc = 1 THEN
                                           CAST(c.notas AS VARCHAR(500))
                                       ELSE
                                           NULL
                                   END
                               ),
       [ACCES_Bahía ] = MAX(   CASE
                                   WHEN (
                                            c.id_cot_cotizacion IS NULL
                                            AND c.id_tipo_cita IN ( 7, 8, 9 )
                                        )
                                        OR c.es_inns_acc = 1 THEN
                                       c.bahia
                                   ELSE
                                       NULL
                               END
                           ),
       [ACCES_Estado] = MAX(   CASE
                                   WHEN (
                                            c.id_cot_cotizacion IS NULL
                                            AND c.id_tipo_cita IN ( 7, 8, 9 )
                                        )
                                        OR c.es_inns_acc = 1 THEN
                                       c.Estado
                                   ELSE
                                       NULL
                               END
                           ),
       [ACCES_Notas Orden] = MAX(   CASE
                                        WHEN (
                                                 c.id_cot_cotizacion IS NULL
                                                 AND c.id_tipo_cita IN ( 7, 8, 9 )
                                             )
                                             OR c.es_inns_acc = 1 THEN
                                            CAST(c.Notas_orden AS VARCHAR(500))
                                        ELSE
                                            NULL
                                    END
                                ),
       [AFTERM_Fecha de cita] = MAX(   CASE
                                           WHEN (
                                                    c.id_cot_cotizacion IS NULL
                                                    AND c.id_tipo_cita IN ( 12 )
                                                )
                                                OR c.es_after = 1 THEN
                                               c.fecha_cita
                                           ELSE
                                               NULL
                                       END
                                   ),
       [AFTERM_Nro. Cita] = MAX(   CASE
                                       WHEN (
                                                c.id_cot_cotizacion IS NULL
                                                AND c.id_tipo_cita IN ( 12 )
                                            )
                                            OR c.es_after = 1 THEN
                                           c.id
                                       ELSE
                                           NULL
                                   END
                               ),
       [AFTERM_Notas Cita] = MAX(   CASE
                                        WHEN (
                                                 c.id_cot_cotizacion IS NULL
                                                 AND c.id_tipo_cita IN ( 12 )
                                             )
                                             OR c.es_after = 1 THEN
                                            CAST(c.notas AS VARCHAR(500))
                                        ELSE
                                            NULL
                                    END
                                ),
       [AFTERM_Bahía ] = MAX(   CASE
                                    WHEN (
                                             c.id_cot_cotizacion IS NULL
                                             AND c.id_tipo_cita IN ( 12 )
                                         )
                                         OR c.es_after = 1 THEN
                                        c.bahia
                                    ELSE
                                        NULL
                                END
                            ),
       [AFTERM_Estado] = MAX(   CASE
                                    WHEN (
                                             c.id_cot_cotizacion IS NULL
                                             AND c.id_tipo_cita IN ( 12 )
                                         )
                                         OR c.es_after = 1 THEN
                                        c.Estado
                                    ELSE
                                        NULL
                                END
                            ),
       [AFTERM_Notas Orden] = MAX(   CASE
                                         WHEN (
                                                  c.id_cot_cotizacion IS NULL
                                                  AND c.id_tipo_cita IN ( 12 )
                                              )
                                              OR c.es_after = 1 THEN
                                             CAST(c.Notas_orden AS VARCHAR(500))
                                         ELSE
                                             NULL
                                     END
                                 ),
       Estadocita = MAX(c.Estadocita)
INTO #CitasPDI
FROM
(
    SELECT c.id_cot_cotizacionfac,
           c.id_tipo_cita,
           c.descripcion,
           c.id,
           c.id_cot_bodega,
           c.id_cot_item_lote,
           c.fecha_creacion,
           c.fecha_cita,
           c.notas,
           c.id_cot_cotizacion,
           Notas_orden = co.notas,
           es_pdi = CASE
                        WHEN b.id = 1679 THEN
                            1
                        ELSE
                            0
                    END,
           es_inns_acc = CASE
                             WHEN b.id = 1683 THEN
                                 1
                             ELSE
                                 0
                         END,
           es_after = CASE
                          WHEN b.id IN ( 1735, 1739 ) THEN
                              1
                          ELSE
                              0
                      END,
           es_kitoblogatorio = CASE
                                   WHEN b.id = 1685 THEN
                                       1
                                   ELSE
                                       0
                               END,
           Estado = CASE
                        WHEN fv.id_cot_cotizacion IS NOT NULL THEN
                            'OK'
                        ELSE
                            ISNULL(otesat.descripcion, '')
                    END + ' ' + CAST(co.id AS VARCHAR),
           c.bahia,
           Estadocita = ISNULL(c.desestadocita, '')
    FROM #VehCitasPDIEntrega c
        LEFT JOIN dbo.cot_cotizacion co
            ON co.id = c.id_cot_cotizacion
        LEFT JOIN dbo.cot_tipo t
            ON t.sw = co.id_cot_tipo
        LEFT JOIN dbo.cot_item_cam cm
            ON cm.id_cot_cotizacion = co.id
               AND cm.id_cot_item_cam_def = 1487
        LEFT JOIN dbo.cot_item_cam_combo b
            ON cm.id_cot_item_cam_def = b.id_cot_item_cam_def
               AND cm.id_cot_item_cam_combo = b.id
               AND b.id IN ( 1683, 1679, 1683, 1735, 1739, 1685 )
        LEFT JOIN dbo.cot_bodega_ubicacion otesat
            ON otesat.id = co.id_cot_bodega_ubicacion
        LEFT JOIN dbo.v_tal_ya_fue_facturado fv
            ON fv.id_cot_cotizacion_sig = co.id
    WHERE c.id_tipo_cita IN ( 7, 8, 9, 10, 11, 12 )
          AND c.id =
          (
              SELECT MAX(c2.id)
              FROM #VehCitasPDIEntrega c2
              WHERE c2.id_cot_item_lote = c.id_cot_item_lote
                    AND c2.id_tipo_cita = c.id_tipo_cita
          )
) c
GROUP BY c.id_cot_cotizacionfac,
         c.id_cot_item_lote

  

------- 04022021

------  ordenes de taller	 GMAH 750
--se pide validar las ordenes de manera independiente , en algunos casos on se carga la cita

SELECT v.id,
       v.id_cot_item,
       v.id_cot_item_lote,
       ot = co.id,
       id_cot_item_cam_combo = b.id,
       Estado = ISNULL(otesat.descripcion, '') + ' ' + CAST(co.id AS VARCHAR)
                + ISNULL(   ' Estado: ' + CASE ISNULL(co.anulada, 0)
                                              WHEN 0 THEN
                                                  NULL --obligatorio dejarlo en NULL
                                              WHEN 1 THEN
                                                  'Fact'
                                              WHEN 2 THEN
                                                  'Bloq'
                                              WHEN 3 THEN
                                                  'Parc'
                                                       --jdms 670
                                              --WHEN 4 THEN 'Anu' ELSE 'Otr' END,
                                              WHEN 4 THEN
                                                  CASE
                                                      WHEN LEFT(CAST(co.notas AS VARCHAR(6)), 6) = '*cons*' THEN
                                                          'Cons'
                                                      ELSE
                                                          'Anu'
                                                  END
                                              ELSE
                                                  'Otr'
                                          END,
                            ''
                        )
INTO #ordenesPdiAfetAcc
FROM dbo.cot_cotizacion co
    JOIN #Veh v
        ON v.id_cot_item_lote = co.id_cot_item_lote
    JOIN dbo.cot_tipo t
        ON t.id = co.id_cot_tipo
           AND t.sw IN ( 46 )
    JOIN dbo.cot_item_cam cm
        ON cm.id_cot_cotizacion = co.id
           AND cm.id_cot_item_cam_def IN ( 1487, 1505 )
    JOIN dbo.cot_item_cam_combo b
        ON cm.id_cot_item_cam_def = b.id_cot_item_cam_def
           AND cm.id_cot_item_cam_combo = b.id
           AND b.id IN ( 1683, 1679, 1683, 1735, 1739, 1685 )
    LEFT JOIN dbo.cot_bodega_ubicacion otesat
        ON otesat.id = co.id_cot_bodega_ubicacion
    LEFT JOIN dbo.v_tal_ya_fue_facturado fv
        ON fv.id_cot_cotizacion_sig = co.id

SELECT c.id,
       c.id_cot_item,
       c.id_cot_item_lote,
       c.id_cot_item_cam_combo,
	   NotasOrden=STUFF(
                     (
                         SELECT ' |* ' + Estado
                         FROM #ordenesPdiAfetAcc a
                         WHERE c.id=a.id AND c.id_cot_item=a.id_cot_item AND c.id_cot_item_lote=a.id_cot_item_lote 
						 AND c.id_cot_item_cam_combo=a.id_cot_item_cam_combo
                               
                         FOR XML PATH('')
                     ),
                     1,
                     1,
                     ''
                          )
 INTO #ordenesPdiAfetAcc_resu
FROM #ordenesPdiAfetAcc	 c
GROUP BY c.id,
         c.id_cot_item,
         C.id_cot_item_lote,
         C.id_cot_item_cam_combo

SELECT 
c.id_cot_cotizacionfac, 
c.id_cot_item_lote,
[PDI_Notas Orden]=CASE WHEN c.[PDI_Notas Orden] IS NULL AND OT.id_cot_item_cam_combo =1679 THEN OT.NotasOrden ELSE c.[PDI_Notas Orden]  END,
[KITMAN_Notas Orden]=CASE WHEN c.[KITMAN_Notas Orden] IS NULL AND OT.id_cot_item_cam_combo=1685 THEN OT.NotasOrden ELSE c.[KITMAN_Notas Orden] END,
[ACCES_Notas Orden]=CASE WHEN c.[ACCES_Notas Orden] IS NULL AND OT.id_cot_item_cam_combo=1683 THEN OT.NotasOrden ELSE c.[ACCES_Notas Orden] END,
[AFTERM_Notas Orden]=CASE WHEN c.[AFTERM_Notas Orden] IS NULL AND OT.id_cot_item_cam_combo IN (1735,1739) THEN ot.NotasOrden ELSE c.[AFTERM_Notas Orden] END 
INTO #ordenesfinal
FROM #CitasPDI	 c
JOIN #ordenesPdiAfetAcc_resu ot
ON ot.id=c.id_cot_cotizacionfac
AND ot.id_cot_item_lote=c.id_cot_item_lote


UPDATE p
SET p.[PDI_Notas Orden]=f.[PDI_Notas Orden],
p.[KITMAN_Notas Orden]=f.[KITMAN_Notas Orden],
p.[ACCES_Notas Orden]=f.[ACCES_Notas Orden],
p.[AFTERM_Notas Orden]=f.[AFTERM_Notas Orden]
FROM #ordenesfinal f
JOIN #CitasPDI p
ON p.id_cot_cotizacionfac=f.id_cot_cotizacionfac
AND p.id_cot_item_lote=f.id_cot_item_lote


------------- FIN VALIDAR ORDENES
---DATOS CITA DE ENTREGA VH
SELECT 
DISTINCT
c.id_cot_cotizacionfac,
       c.id_cot_item_lote,
       [ENTREGA_Fecha de cita] = c.fecha_cita,
       [ENTREGA_Nro. Cita] = c.id,
       [ENTREGA_Notas Cita] = c.notas,
       [ENTREGA_Bahía ] = c.bahia,
       [ENTREGA_Estado] = CASE
                              WHEN fv.id_cot_cotizacion IS NOT NULL THEN
                                  'OK'
                              ELSE
                                  otesat.descripcion
                          END + ' ' + CAST(co.id AS VARCHAR),
       [ENTREGA_Sede ] = cb.descripcion,
       Estadocita = c.desestadocita
INTO #citaEntrega
FROM #VehCitasPDIEntrega c
    JOIN dbo.cot_bodega cb
        ON cb.id = c.id_cot_bodega AND c.id_tipo_cita = 3
    LEFT JOIN dbo.cot_cotizacion co
        ON co.id = c.id_cot_cotizacion
    LEFT JOIN dbo.cot_tipo t
        ON t.sw = co.id_cot_tipo
    LEFT JOIN dbo.cot_bodega_ubicacion otesat
        ON otesat.id = co.id_cot_bodega_ubicacion
    LEFT JOIN dbo.v_tal_ya_fue_facturado fv
        ON fv.id_cot_cotizacion_sig = co.id
WHERE 
       c.id =
      (
          SELECT MAX(c2.id)
          FROM #VehCitasPDIEntrega c2
          WHERE c2.id_cot_item_lote = c.id_cot_item_lote
                AND c2.id_tipo_cita = c.id_tipo_cita
				AND c2.id_tipo_cita=3
      )


	

---Datos Ped AFTERMARKET
SELECT v.id,
       p.id_cot_item_lote,
       -- p.id, 
       ci.codigo,
       ci.descripcion,
       cpi.cantidad,
       cpi.precio_cotizado,
       co.fecha,
       que = CASE
                 WHEN b.id = 1738 THEN
                     'D'
                 ELSE
                     'AM'
             END
INTO #vehpedidos_aftermarket
FROM #Veh v
    JOIN dbo.cot_pedido p
        ON p.id_cot_item_lote = v.id_cot_item_lote
    JOIN dbo.cot_item_cam c
        ON c.id_cot_pedido = p.id
    JOIN dbo.cot_item_cam_combo b
        ON c.id_cot_item_cam_def = b.id_cot_item_cam_def
           AND c.id_cot_item_cam_combo = b.id
           AND b.id IN ( 1735, 1738 )
    JOIN dbo.cot_pedido_item cpi
        ON cpi.id_cot_pedido = p.id
    JOIN dbo.cot_item ci
        ON ci.id = cpi.id_cot_item
    JOIN dbo.cot_cotizacion_item i
        ON i.id_cot_pedido_item = cpi.id
    JOIN dbo.cot_cotizacion co
        ON co.id = i.id_cot_cotizacion
    JOIN dbo.cot_tipo ct
        ON ct.id = co.id_cot_tipo
           AND ct.sw = 1
WHERE p.id_cot_item_lote IS NOT NULL






SELECT v.id,
       v.id_cot_item_lote,
       fecha = MAX(v.fecha),
       AFTERMARKET = STUFF(
                     (
                         SELECT ' | Código:' + a.codigo + '-Descripción:' + a.descripcion + '-'
                                + CAST(CAST(a.cantidad AS DECIMAL(18, 2)) AS VARCHAR) + '-'
                                + CAST(a.precio_cotizado AS VARCHAR)
                         FROM #vehpedidos_aftermarket a
                         WHERE a.id_cot_item_lote = v.id_cot_item_lote
                               AND a.que = 'AM'
                         FOR XML PATH('')
                     ),
                     1,
                     1,
                     ''
                          )
INTO #vehpedidos_aftermarket_re
FROM #vehpedidos_aftermarket v
WHERE v.que = 'AM'
GROUP BY v.id,
         v.id_cot_item_lote,
         v.que



------------------------------------------------------------
SELECT v.id,
       v.id_cot_item_lote,
       fecha = MAX(v.fecha),
       PedidoDispositivo = STUFF(
                           (
                               SELECT ' | Código:' + a.codigo + '-Descripción:' + a.descripcion + '-'
                                      + CAST(CAST(a.cantidad AS DECIMAL(18, 2)) AS VARCHAR) + '-'
                                      + CAST(a.precio_cotizado AS VARCHAR)
                               FROM #vehpedidos_aftermarket a
                               WHERE a.id_cot_item_lote = v.id_cot_item_lote
                                     AND a.que = 'D'
                               FOR XML PATH('')
                           ),
                           1,
                           1,
                           ''
                                )
INTO #vehpedidos_ped_re
FROM #vehpedidos_aftermarket v
WHERE v.que = 'D'
GROUP BY v.id,
         v.id_cot_item_lote,
         v.que




--------------------------------------------------------------

	delete tmpFactVisorMepai
 
	Insert into tmpFactVisorMepai


	SELECT 
		   [Emp]=@emp,
		   [fechaCorte]=Convert(datetime,Convert(varchar,DateAdd(month, 1, DateAdd(day, -day(GETDATE()) + 1, GETDATE())), 112)) - 1, 
		   [Marca] = v.marca,
		   [Agencia] = cb.descripcion,
		   [Fecha_Fac] = d.fecha,
		   [Plan_Venta] = CASE
							  WHEN v.tipo_veh IN ( 1, 2, 3 ) THEN
								  'USADO'
							  ELSE
								  'NUEVO'
						  END,
		   [Tipo_fac] = d.descripcion,
		   [ID] = d.id,
		   [Numero_fac] = CAST(ISNULL(cb.ecu_establecimiento, '') AS VARCHAR) + CAST(ISNULL(d.ecu_emision, '0') AS VARCHAR)
						  + '-' + CAST(ISNULL(RIGHT('000000000' + LTRIM(RTRIM(d.numero_cotizacion)), 9), '') AS VARCHAR),
		   [Numero_HN] = d.id_veh_hn_enc,
		   [Tipo_Negocio] = hne.Tipo_Negocio,
		   [Nomb_flota] = hne.Nomb_flota,
		   [ChevyPlan] = hne.ChevyPlan,
		   [Chasis] = v.chasis,
		   [Modelo] = v.modeloano,
		   [Color] = v.color,
		   [Accesorios] = ISNULL(vhacc.accesorios, ''),
		   [Accesorios del cliente] = ere.Accesorio_de_Cliente,
		   --,[Novedad Accesorio de Cliente]=ere.Accesorio_de_Cliente       
		   [Apli_rebate] = ISNULL(hnp.Apli_rebate, 'NO'),
		   [Val_Rebate] = ISNULL(hnp.Val_Rebate, 0),
		   [Cliente] = t.razon_social,
		   [Vendedor] = u.nombre,
		   [Forma_Pago] = ISNULL(fpr.Forma_Pago, 'Contado'),
		   [Aseguradora] = hne.Aseguradora,
		   [Fianciera] = fpr.Financiera,
		   [Fec_Apro_fi] = fpr.Fec_Apro_fi,
		   [Tipo_Cre] = hne.Tipo_Credito,
		   [Facturador] = uf.nombre,	   
		   [Valor_anti] = fpr.Valor_anti,
		   [Valor_fin] = fpr.Valor_fin,
		   [Valor_NotaCredito] = fpr.Valor_NotaCredito,
		   [valor_cuota_diferido] = 0,
		   [Valor_CD] = hncd.Valor_CD,
		   [Valor_Vh_US] = fpr.Valor_Vh_US,       
		   [Saldo_Finan] = fpr.Saldo_Finan,
		   [Saldo_cli] = vs.saldo,
		   [Estado] = eshncar.estado + ' - ' + FORMAT(eshncar.fecha, 'dd/MM/yyyy'),
		   [Nota status cartera] = eshncar.notas,
		   [Fecha_docs] = df.Fecha_docs,
		   [Dias_facts] = df.Dias_facts,
		   [Fec_Notaria] = df.Fec_Notaria,
		   [Dias_Env_not] = df.Dias_Env_not,
		   [Fecha_Fir_cont] = df.Fecha_Fir_cont,
		   [Dias_firm_cont] = df.Dias_firm_cont,
		   [Ubic_veh] = v.Ubic_veh,       
		   cpdi.[KITMAN_Fecha de cita],
		   cpdi.[KITMAN_Nro. Cita],
		   cpdi.[KITMAN_Notas Cita],
		   cpdi.[KITMAN_Bahía ],
		   KITMAN_Estado = CASE
							   WHEN cpdi.[KITMAN_Nro. Cita] IS NOT NULL THEN
								   ISNULL(cpdi.KITMAN_Estado, cpdi.Estadocita)
						   END,
		   cpdi.[KITMAN_Notas Orden],
		   cpdi.[PDI_Fecha de cita],
		   cpdi.[PDI_Nro. Cita],
		   cpdi.[PDI_Notas Cita],
		   cpdi.[PDI_Bahía ],
		   PDI_Estado = CASE
							WHEN cpdi.[PDI_Nro. Cita] IS NOT NULL THEN
								ISNULL(cpdi.PDI_Estado, cpdi.Estadocita)
							ELSE
								''
						END,
		   cpdi.[PDI_Notas Orden],
		   cpdi.[ACCES_Fecha de cita],
		   cpdi.[ACCES_Nro. Cita],
		   cpdi.[ACCES_Notas Cita],
		   cpdi.[ACCES_Bahía ],
		   [ACCES_Estado] = CASE
								WHEN cpdi.[ACCES_Nro. Cita] IS NOT NULL THEN
									ISNULL(cpdi.ACCES_Estado, cpdi.Estadocita)
								ELSE
									''
							END,
		   cpdi.[ACCES_Notas Orden],
		   [Entrega_Logis] = ver.Entrega_Logis,       
		   [Dispositivo] = hne.Dispositivo,
		   [Estado_disp] = ver.EstadoDispositivo,
		   [FechaInstalacion] = ver.fecha_instal_dispo,
		   [Factura_disp] = disre.fecha,
		   [Dispositivos Pedido] = disre.PedidoDispositivo,
		   [Fecha AfterMaret] = pafr.fecha,
		   [Accesorios] = pafr.AFTERMARKET,
		   cpdi.[AFTERM_Fecha de cita],
		   cpdi.[AFTERM_Nro. Cita],
		   cpdi.[AFTERM_Notas Cita],
		   cpdi.[AFTERM_Bahía ],
		   [AFTERM_Estado] = CASE
								 WHEN cpdi.[AFTERM_Nro. Cita] IS NOT NULL THEN
									 ISNULL(cpdi.AFTERM_Estado, cpdi.Estadocita)
								 ELSE
									 ''
							 END,
		   cpdi.[AFTERM_Notas Orden],
		   [Obsequios] = CAST(ISNULL(
							  (
								  SELECT '1.- ' + ISNULL(cb.descripcion, '') + ' = ' + ISNULL(ca.contenido, '')
								  FROM dbo.cot_item_cam ca
									  LEFT JOIN dbo.cot_item_cam_combo cb
										  ON cb.id = ca.id_cot_item_cam_combo
								  WHERE cb.descripcion LIKE '%matricula gratis%'
										AND ca.id_veh_hn_enc = d.id_veh_hn_enc
							  ),
							  ''
									) + ISNULL(
										(
											SELECT ' 2.- ' + ISNULL(cb.descripcion, '') + ' = ' + ISNULL(ca.contenido, '')
											FROM dbo.cot_item_cam ca
												LEFT JOIN dbo.cot_item_cam_combo cb
													ON cb.id = ca.id_cot_item_cam_combo
											WHERE cb.descripcion LIKE '%mantenimient%'
												  AND ca.id_veh_hn_enc = d.id_veh_hn_enc
										),
										''
											  ) AS VARCHAR(MAX)),
		   [Acceso_externa] = ver.Acceso_externa,
		   [fecha_ent_acc_ext] = ver.fecha_ent_acc_ext,
		   [Accesorios Externos] = ver.notas_acces_externa,
		   [Autorizacion matriculacion] = FORMAT(eshnmat.fecha, 'dd/MM/yyyy') + ' ' + ISNULL(eshnmat.notas, '')
										  + ' Usuario: ',
		   [Envio_Matricula] = ver.Envio_Matricula,
		   [Matriculado] = ver.Matriculado,
		   [Gestor] = v.Gestor,
		   [Dias_Matri] = DATEDIFF(DAY, CAST(ver.Envio_Matricula AS DATE), ISNULL(ver.Matriculado, CAST(GETDATE() AS DATE)))
						  - dbo.fn_dias_nolaborales(
													   CAST(ver.Envio_Matricula AS DATE),
													   ISNULL(ver.Matriculado, CAST(GETDATE() AS DATE))
												   ),
		   [Placa] = CASE
						 WHEN ver.Matriculado IS NULL THEN
							 ''
						 ELSE
							 v.Placa
					 END,
		   [Excepcion] = ere.Excepciones,
		   [Quien_Autorizo] = ere.desc_en_manos_de,
		   [Fec_pro_regula] = ere.Fec_pro_regula,
		   [Documntos_pendientes] = dre.Documentos_pendientes,
		   [Novedad_Evento] = ere.NovedadEvento,
		   cent.[ENTREGA_Fecha de cita],
		   cent.[ENTREGA_Nro. Cita],
		   cent.[ENTREGA_Notas Cita],
		   [Tecnico] = cent.[ENTREGA_Bahía ],
		   [ENTREGA_Estado] = CASE
								  WHEN cent.[ENTREGA_Nro. Cita] IS NOT NULL THEN
									  ISNULL(cent.ENTREGA_Estado, cent.Estadocita)
								  ELSE
									  ''
							  END,
		   [Agencia] = cent.[ENTREGA_Sede ],
		   [Promesa_entrega] = hne.fecha_estimada_entrega,
		   [Fec_tenta_entre] = CASE
								   -- se valida que la fecha termine  en sabado para pasar al lunes
								   WHEN DATEPART(
													dw,
													CASE
														WHEN v.lineavh = 687
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														8,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 8, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 687
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														18,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 18, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 688
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														10,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 10, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 688
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														20,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 20, CAST(d.fecha AS DATE))
																   )
													END
												) = 7 THEN
									   DATEADD(
												  d,
												  2,
												  CASE
													  WHEN v.lineavh = 687
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  8,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 8, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 687
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  18,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 18, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 688
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  10,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 10, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 688
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  20,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 20, CAST(d.fecha AS DATE))
																 )
												  END
											  )
								   -- se valida que la fecha termine en domingo  para pasar al lunes
								   WHEN DATEPART(
													dw,
													CASE
														WHEN v.lineavh = 687
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														8,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 8, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 687
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														18,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 18, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 688
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														10,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 10, CAST(d.fecha AS DATE))
																   )
														WHEN v.lineavh = 688
															 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															DATEADD(
																	   d,
																	   (dbo.fn_dias_nolaborales(
																								   CAST(d.fecha AS DATE),
																								   ISNULL(
																											 DATEADD(
																														d,
																														20,
																														CAST(d.fecha AS DATE)
																													),
																											 CAST(GETDATE() AS DATE)
																										 )
																							   )
																	   ),
																	   DATEADD(d, 20, CAST(d.fecha AS DATE))
																   )
													END
												) = 1 THEN
									   DATEADD(
												  d,
												  1,
												  CASE
													  WHEN v.lineavh = 687
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  8,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 8, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 687
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  18,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 18, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 688
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  10,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 10, CAST(d.fecha AS DATE))
																 )
													  WHEN v.lineavh = 688
														   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														  DATEADD(
																	 d,
																	 (dbo.fn_dias_nolaborales(
																								 CAST(d.fecha AS DATE),
																								 ISNULL(
																										   DATEADD(
																													  d,
																													  20,
																													  CAST(d.fecha AS DATE)
																												  ),
																										   CAST(GETDATE() AS DATE)
																									   )
																							 )
																	 ),
																	 DATEADD(d, 20, CAST(d.fecha AS DATE))
																 )
												  END
											  )
								   ELSE
									   CASE
										   WHEN v.lineavh = 687
												AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
											   DATEADD(
														  d,
														  (dbo.fn_dias_nolaborales(
																					  CAST(d.fecha AS DATE),
																					  ISNULL(
																								DATEADD(
																										   d,
																										   8,
																										   CAST(d.fecha AS DATE)
																									   ),
																								CAST(GETDATE() AS DATE)
																							)
																				  )
														  ),
														  DATEADD(d, 8, CAST(d.fecha AS DATE))
													  )
										   WHEN v.lineavh = 687
												AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
											   DATEADD(
														  d,
														  (dbo.fn_dias_nolaborales(
																					  CAST(d.fecha AS DATE),
																					  ISNULL(
																								DATEADD(
																										   d,
																										   18,
																										   CAST(d.fecha AS DATE)
																									   ),
																								CAST(GETDATE() AS DATE)
																							)
																				  )
														  ),
														  DATEADD(d, 18, CAST(d.fecha AS DATE))
													  )
										   WHEN v.lineavh = 688
												AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
											   DATEADD(
														  d,
														  (dbo.fn_dias_nolaborales(
																					  CAST(d.fecha AS DATE),
																					  ISNULL(
																								DATEADD(
																										   d,
																										   10,
																										   CAST(d.fecha AS DATE)
																									   ),
																								CAST(GETDATE() AS DATE)
																							)
																				  )
														  ),
														  DATEADD(d, 10, CAST(d.fecha AS DATE))
													  )
										   WHEN v.lineavh = 688
												AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
											   DATEADD(
														  d,
														  (dbo.fn_dias_nolaborales(
																					  CAST(d.fecha AS DATE),
																					  ISNULL(
																								DATEADD(
																										   d,
																										   20,
																										   CAST(d.fecha AS DATE)
																									   ),
																								CAST(GETDATE() AS DATE)
																							)
																				  )
														  ),
														  DATEADD(d, 20, CAST(d.fecha AS DATE))
													  )
									   END
							   END,
		   --,[Comentario]=''
		   --,[Plan_Accion]=''
		   [Tot_dias_Entre] = DATEDIFF(
										  d,
										  (CASE
											   -- se valida que la fecha termine  en sabado para pasar al lunes
											   WHEN DATEPART(
																dw,
																CASE
																	WHEN v.lineavh = 687
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	8,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 8, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 687
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	18,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 18, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 688
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	10,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 10, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 688
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	20,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 20, CAST(d.fecha AS DATE))
																			   )
																END
															) = 7 THEN
												   DATEADD(
															  d,
															  2,
															  CASE
																  WHEN v.lineavh = 687
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  8,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 8, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 687
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  18,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 18, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 688
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  10,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 10, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 688
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  20,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 20, CAST(d.fecha AS DATE))
																			 )
															  END
														  )
											   -- se valida que la fecha termine en domingo  para pasar al lunes
											   WHEN DATEPART(
																dw,
																CASE
																	WHEN v.lineavh = 687
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	8,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 8, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 687
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	18,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 18, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 688
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	10,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 10, CAST(d.fecha AS DATE))
																			   )
																	WHEN v.lineavh = 688
																		 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																		DATEADD(
																				   d,
																				   (dbo.fn_dias_nolaborales(
																											   CAST(d.fecha AS DATE),
																											   ISNULL(
																														 DATEADD(
																																	d,
																																	20,
																																	CAST(d.fecha AS DATE)
																																),
																														 CAST(GETDATE() AS DATE)
																													 )
																										   )
																				   ),
																				   DATEADD(d, 20, CAST(d.fecha AS DATE))
																			   )
																END
															) = 1 THEN
												   DATEADD(
															  d,
															  1,
															  CASE
																  WHEN v.lineavh = 687
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  8,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 8, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 687
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  18,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 18, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 688
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  10,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 10, CAST(d.fecha AS DATE))
																			 )
																  WHEN v.lineavh = 688
																	   AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																	  DATEADD(
																				 d,
																				 (dbo.fn_dias_nolaborales(
																											 CAST(d.fecha AS DATE),
																											 ISNULL(
																													   DATEADD(
																																  d,
																																  20,
																																  CAST(d.fecha AS DATE)
																															  ),
																													   CAST(GETDATE() AS DATE)
																												   )
																										 )
																				 ),
																				 DATEADD(d, 20, CAST(d.fecha AS DATE))
																			 )
															  END
														  )
											   ELSE
												   CASE
													   WHEN v.lineavh = 687
															AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														   DATEADD(
																	  d,
																	  (dbo.fn_dias_nolaborales(
																								  CAST(d.fecha AS DATE),
																								  ISNULL(
																											DATEADD(
																													   d,
																													   8,
																													   CAST(d.fecha AS DATE)
																												   ),
																											CAST(GETDATE() AS DATE)
																										)
																							  )
																	  ),
																	  DATEADD(d, 8, CAST(d.fecha AS DATE))
																  )
													   WHEN v.lineavh = 687
															AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														   DATEADD(
																	  d,
																	  (dbo.fn_dias_nolaborales(
																								  CAST(d.fecha AS DATE),
																								  ISNULL(
																											DATEADD(
																													   d,
																													   18,
																													   CAST(d.fecha AS DATE)
																												   ),
																											CAST(GETDATE() AS DATE)
																										)
																							  )
																	  ),
																	  DATEADD(d, 18, CAST(d.fecha AS DATE))
																  )
													   WHEN v.lineavh = 688
															AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
														   DATEADD(
																	  d,
																	  (dbo.fn_dias_nolaborales(
																								  CAST(d.fecha AS DATE),
																								  ISNULL(
																											DATEADD(
																													   d,
																													   10,
																													   CAST(d.fecha AS DATE)
																												   ),
																											CAST(GETDATE() AS DATE)
																										)
																							  )
																	  ),
																	  DATEADD(d, 10, CAST(d.fecha AS DATE))
																  )
													   WHEN v.lineavh = 688
															AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
														   DATEADD(
																	  d,
																	  (dbo.fn_dias_nolaborales(
																								  CAST(d.fecha AS DATE),
																								  ISNULL(
																											DATEADD(
																													   d,
																													   20,
																													   CAST(d.fecha AS DATE)
																												   ),
																											CAST(GETDATE() AS DATE)
																										)
																							  )
																	  ),
																	  DATEADD(d, 20, CAST(d.fecha AS DATE))
																  )
												   END
										   END
										  ),
										  CAST(ISNULL(hne.VH_Entregado, GETDATE()) AS DATE)
									  )
							  - dbo.fn_dias_nolaborales ---restar lo dias  no laboraes al final del calculo
								(
									CASE
										-- se valida que la fecha termine  en sabado para pasar al lunes
										WHEN DATEPART(
														 dw,
														 CASE
															 WHEN v.lineavh = 687
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 8,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 8, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 687
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 18,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 18, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 688
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 10,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 10, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 688
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 20,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 20, CAST(d.fecha AS DATE))
																		)
														 END
													 ) = 7 THEN
											DATEADD(
													   d,
													   2,
													   CASE
														   WHEN v.lineavh = 687
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   8,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 8, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 687
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   18,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 18, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 688
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   10,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 10, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 688
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   20,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 20, CAST(d.fecha AS DATE))
																	  )
													   END
												   )
										-- se valida que la fecha termine en domingo  para pasar al lunes
										WHEN DATEPART(
														 dw,
														 CASE
															 WHEN v.lineavh = 687
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 8,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 8, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 687
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 18,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 18, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 688
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 10,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 10, CAST(d.fecha AS DATE))
																		)
															 WHEN v.lineavh = 688
																  AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
																 DATEADD(
																			d,
																			(dbo.fn_dias_nolaborales(
																										CAST(d.fecha AS DATE),
																										ISNULL(
																												  DATEADD(
																															 d,
																															 20,
																															 CAST(d.fecha AS DATE)
																														 ),
																												  CAST(GETDATE() AS DATE)
																											  )
																									)
																			),
																			DATEADD(d, 20, CAST(d.fecha AS DATE))
																		)
														 END
													 ) = 1 THEN
											DATEADD(
													   d,
													   1,
													   CASE
														   WHEN v.lineavh = 687
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   8,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 8, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 687
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   18,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 18, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 688
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   10,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 10, CAST(d.fecha AS DATE))
																	  )
														   WHEN v.lineavh = 688
																AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
															   DATEADD(
																		  d,
																		  (dbo.fn_dias_nolaborales(
																									  CAST(d.fecha AS DATE),
																									  ISNULL(
																												DATEADD(
																														   d,
																														   20,
																														   CAST(d.fecha AS DATE)
																													   ),
																												CAST(GETDATE() AS DATE)
																											)
																								  )
																		  ),
																		  DATEADD(d, 20, CAST(d.fecha AS DATE))
																	  )
													   END
												   )
										ELSE
											CASE
												WHEN v.lineavh = 687
													 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
													DATEADD(
															   d,
															   (dbo.fn_dias_nolaborales(
																						   CAST(d.fecha AS DATE),
																						   ISNULL(
																									 DATEADD(
																												d,
																												8,
																												CAST(d.fecha AS DATE)
																											),
																									 CAST(GETDATE() AS DATE)
																								 )
																					   )
															   ),
															   DATEADD(d, 8, CAST(d.fecha AS DATE))
														   )
												WHEN v.lineavh = 687
													 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
													DATEADD(
															   d,
															   (dbo.fn_dias_nolaborales(
																						   CAST(d.fecha AS DATE),
																						   ISNULL(
																									 DATEADD(
																												d,
																												18,
																												CAST(d.fecha AS DATE)
																											),
																									 CAST(GETDATE() AS DATE)
																								 )
																					   )
															   ),
															   DATEADD(d, 18, CAST(d.fecha AS DATE))
														   )
												WHEN v.lineavh = 688
													 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Contado' THEN
													DATEADD(
															   d,
															   (dbo.fn_dias_nolaborales(
																						   CAST(d.fecha AS DATE),
																						   ISNULL(
																									 DATEADD(
																												d,
																												10,
																												CAST(d.fecha AS DATE)
																											),
																									 CAST(GETDATE() AS DATE)
																								 )
																					   )
															   ),
															   DATEADD(d, 10, CAST(d.fecha AS DATE))
														   )
												WHEN v.lineavh = 688
													 AND ISNULL(fpr.Forma_Pago, 'Contado') = 'Crédito' THEN
													DATEADD(
															   d,
															   (dbo.fn_dias_nolaborales(
																						   CAST(d.fecha AS DATE),
																						   ISNULL(
																									 DATEADD(
																												d,
																												20,
																												CAST(d.fecha AS DATE)
																											),
																									 CAST(GETDATE() AS DATE)
																								 )
																					   )
															   ),
															   DATEADD(d, 20, CAST(d.fecha AS DATE))
														   )
											END
									END,
									CAST(ISNULL(hne.VH_Entregado, GETDATE()) AS DATE)
								),

		   [VH_Entregado] =-- CAST(hne.VH_Entregado AS DATE),
		    CASE 
							WHEN  CAST(hne.VH_Entregado AS DATE) IS NOT NULL THEN CAST(hne.VH_Entregado AS DATE) 
							ELSE 
								CASE WHEN hne.Estadohn=575 THEN hne.fechaultimocambio ELSE  NULL END ---GMAH 753 --Si no registro auditoria de último evento, toma el estasdo dela HN si es entregado presentará ese datos
							
						END ,
		   [anulado] = d.anulado,
		   [valor_Credito_Consumo] = fpr.valor_CreditoCon,
		   [Ubicacion_Especifica] = v.Ubicacion_Especifica,
		   [Recepcion_logitica] = ver.Recibido_Logistica,
		   [Rebate_Sugerido]=ISNULL(d.valor_rebate_sug,0),
		   [Valor_Factura]=d.total_total
	FROM #Documentos d
		JOIN dbo.cot_cliente t
			ON t.id = d.id_cot_cliente
		JOIN #usuario u
			ON u.id = d.id_usuario_vende
		JOIN #usuario uf
			ON uf.id = d.id_usuario
		JOIN dbo.cot_bodega cb
			ON cb.id = d.id_cot_bodega
		JOIN #Vehiculos v
			ON v.id = d.id
			   AND v.id_cot_item_lote = d.id_cot_item_lote
		JOIN #DatosHN_Enc hne
			ON hne.id = d.id
			   AND hne.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #DatosHN_Ped hnp
			ON hnp.id = d.id
			   AND hnp.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #VehAccesorios vhacc
			ON vhacc.id = d.id
			   AND vhacc.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #DatosHN_Formapresumen fpr
			ON fpr.id = d.id
			   AND fpr.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #DatosHN_CD hncd
			ON hncd.id = d.id
			   AND hncd.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN dbo.v_cot_factura_saldo vs
			ON vs.id_cot_cotizacion = d.id
		LEFT JOIN #DatosDocs_fechas df
			ON df.id = d.id
			   AND df.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #Veheventosresumen ver
			ON ver.id = d.id
			   AND ver.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #ExcepcionesNovedadEvento_res ere
			ON ere.id = d.id
			   AND ere.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #docPendientes_res dre
			ON dre.id = d.id
			   AND dre.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #CitasPDI cpdi
			ON cpdi.id_cot_cotizacionfac = d.id
			   AND cpdi.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #citaEntrega cent
			ON cent.id_cot_cotizacionfac = d.id
			   AND cent.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #vehpedidos_aftermarket_re pafr
			ON pafr.id = d.id
			   AND pafr.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #vehpedidos_ped_re disre
			ON disre.id = d.id
			   AND disre.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #datosEstadoHncartera eshncar
			ON eshncar.id = d.id
			   AND eshncar.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN #datosEstadoHnmatri eshnmat
			ON eshnmat.id = d.id
			   AND eshnmat.id_cot_item_lote = d.id_cot_item_lote
