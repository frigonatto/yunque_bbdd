USE [CodeApp]
GO
/****** Object:  StoredProcedure [dbo].[Spx_AP_Retenciones]    Script Date: 8/17/2023 4:32:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXEC Spx_AP_Retenciones '084225', 'Debug'  --  401383
-- SELECT * FROM xApRetHist WHERE VendId = '10005'
-- DELETE  xApRetHist WHERE VendId = '10005'
-- select * from dbo.xRetencionDet WHERE RefNbr = '019299' order by IdCptoRetencion, WrkRecordId -- IdCptoRetencion, RefNbr
-- select * from dbo.xRetencionDet WHERE OpBatNbr = '287271' 
--TRUN CATE TABLE dbo.xRetencionDet
--

--| |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
--|                     ____                   _    ____  ____      _                  _
--|                    / ___| _ ____  __      / \  |  _ \|  _ \ ___| |_ ___ _ __   ___(_) ___  _ __   ___ ___
--|                    \___ \| '_ \ \/ /     / _ \ | |_) | |_) / _ \ __/ _ \ '_ \ / __| |/ _ \| '_ \ / _ Y __|
--|                     ___) | |_) >  <     / ___ \|  __/|  _ <  __/ ||  __/ | | | (__| | (_) | | | |  __|__ \
--|                    |____/| .__/_/\_\___/_/   \_\_|___|_| \_\___|\__\___|_| |_|\___|_|\___/|_| |_|\___|___/
--|                          |_|      |_____|       |_____|
--| |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
--| 
--| Spx ................: Spx_AP_Retenciones
--| Version ...... .....: 02.02.20
--| Fecha Actualizacion : 2016-Oct-06
--| Fecha Creacion .....: 2009-Jun-15 (Version Inicial 02.00.00)
--| (CODE)(mjc)
--| ...............................................................................................................
--| .:Parametros:.
--| (1) BatNbr ----> VARCHAR(10) -> Lote de la OP (sin liberar) a que se debe Calcular Retenciones
--| (2) User ------> VARCHAR(10) -> Usuario creador de la OP (Si UserId = "Debug", se activa el modo Debug)
--| (3) BugMode ---> BIT -> Default = 0 (1=Modo Debug Activo)
--| ...............................................................................................................
--| .:Descripción:.
--| El proceso calcula las retenciones de los documentos aplicados en la OP correspondiente al lote que se pasa
--| como parámetro.
--| Posee básicamente dos partes, una primera parte en la que calcúla retenciones a nivel de documento (*) y la segunda 
--| donde calcúla a nivel de línea (ApTran de los documentos de la OP que fueron "marcados" con retenciones de ese 
--| tipo.
--| (*) A nivel de documento hay retenciones Automaticas y Manuales
--| ...............................................................................................................
--| .:Estructura:.
--| (PASO 1 ) -Declaración de Variables, seteos de Defaults e inicializaciones
--| (PASO 2 ) -Completa datos y elimina retenciones anteriormente calculadas
--| (PASO 3 ) -Genera un string de Retenciones Válidas que acelera los filtros de Cálculo (Utilizando PATINDEX)
--|           -Verifica de que retenciones es agente la compañía.
--|           -Luego verifica si las retenciones "Especiales" están activas o no (Retenciones Monotributo o Regimen
--|            simplificado). Esto lo debe realizar acá ya que si las retenciones especiales están activas, no es
--|            necesario que la compañía sea agente de retencion. 
--|            Si las retenciones especiales están habilitadas se llama al SP: spx_OnOffFlagRetencion que realiza
--|            las verificaciones correspondientes tanto del proveedor como de los acumulados o padron. Este SP 
--|            retorna un flag. Si es TRUE corresponde calcular, de ser falso, no.
--| (PASO 4a)  Calculo de Retenciones x Documento Manual (Explicado en detalle en cada paso del SP)
--| (PASO 4b)  Calculo de Retenciones x Documento Automatica (Explicado en detalle en cada paso del SP)
--| (PASO 4c)  Calculo de Retenciones x Línea Automática (Explicado en detalle en cada paso del SP)
--| (PASO 5 )  Retorno de los datos a las tablas de OP y otras
--| ...............................................................................................................
--| .:Mapeo de campos Future en xRetencionDet:.
--|      xRetencionDet.S4Future01 -> Control de Version de Motor
--|      xRetencionDet.S4Future02 -> Texto con % de liberacion a proveedor
--|                               -> Texto con alicuota rectificada
--|      xRetencionDet.S4Future03 -> Campo de calculo auxiliar para Neteo dentro de una OP (entre FC vs NC)
--|      xRetencionDet.S4Future04 -> Campo de calculo auxiliar para Neteo dentro de una OP (entre FC vs NC)
--| ...............................................................................................................
--| .:Mapeo de campos User:.
--|      xRetencionDet.User3 = Marca n: Primera/Segunda pasada Base Retencion Flotante 
--|      xRetencionDet.User4 = Porcentaje de reducción de base
--|      xRetencionDet.User5 = Jusrisdicción del proveedor
--|      xRetencionDet.User6 = Auxiliar en el calculo de Retenciones de 4ta categoria
--| ...............................................................................................................
--| .:Bitacora:.
--| (CODE)(2017-09-29)(mjc)(ver: 02.02.20)
--|   -> BugFix: No prevee mismo proveedor en mas de un padrón
--| (CODE)(2017-03-21)(mjc)(ver: 02.02.19) 
--|   -> BugFix: Retenciones Manuales. Fuerza a las Notas de Credito a estar primeras para que nunca tengan el OK.
--| (CODE)(2016-10-06)(mjc)(ver: 02.02.18) 
--|   -> BugFix: Verifica que exista 1 solo cuit en padrón. Padrones con CUITs repetidos. VendId diferentes mismo CUIT en FF
--| (CODE)(2016-10-06)(mjc)(ver: 02.02.17) 
--|   -> UpdFix: Actualizacion de la base retenible flotante AGIP 364/16 (Solo para retenciones NO manuales)
--| (CODE)(2016-05-27)(mjc)(ver: 02.02.16) 
--|   -> UpdFix: Cuando activa y desactiva liberaciones de retenciones segun vigencia, verifica de actualzar solo las activas
--| (CODE)(2013-12-20)(mjc)(ver: 02.02.15) 
--|   -> BugFix: Se corrigieron errores de la version (ver: 02.02.14)
--| (CODE)(2013-12-20)(mjc)(ver: 02.02.14) 
--|   -> UpdFix: Se quitaron todos los DROP y TRUNCATES por temas de permisos restringidos en TempDb
--| (CODE)(2013-12-20)(mjc)(ver: 02.02.13) 
--|   -> BugFix: 4ta Categoria, dejaba lineas demas. Porque al desmarcar lineas de la misma camada de retencion
--|              dejaba mas de un tipo de alicuota (para la misma retencion) activas. Ahora verifica para el la alicuota
--|              más alta (En ganancias acumula por documentos cancelados en una misma OP, por lo que cuando va seleccionado
--|              los primeros documentos caen en categorias mas bajas y va aumentando a medida que el acumulado aumenta)
--| (CODE)(2013-12-20)(mjc)(ver: 02.02.12) 
--|   -> BugFix: Liberacion de % Retencion 
--| (CODE)(2013-12-18)(mjc)(ver: 02.02.11) 
--|   -> BugFix: Se evita que calcule el proporcional dos veces o ninguna (Retenciones Manuales)
--| (CODE)(2013-12-04)(mjc)(ver: 02.02.10) 
--|   -> BugFix: Se actualizo la vista de Retenciones Manuales para que no considere el proporcional (Vw_Ap_ApDocTax_End_Man)
--| (CODE)(2013-11-31)(mjc)(ver: 02.02.09) 
--|   -> UpdFix: Prevee la carga del BasRet en las retenciones manuales.
--| (CODE)(2013-09-06)(mjc)(ver: 02.02.08) (En Nuba es la 02.02.05a asi que Ojo al piojo)
--|   -> UpdFix: 4ta Categoría borraba líneas demas.
--| (CODE)(2012-12-04)(mjc)(Ver: 02.02.07) 
--|   -> UpdFix: Retenciones manuales (nueva categoria) utiliza xConceptoCateg
--| (CODE)(2012-12-04)(mjc)(Ver: 02.02.06a) 
--|   -> UpdFix: Corrige posibles errores en BasRet
--| (CODE)(2012-12-04)(mjc)(Ver: 02.02.06) 
--|   -> UpdFix: Detalle documento de AP basado en la nueva tabla de conceptos (solo para documentos manuales)
--| (CODE)(2012-11-22)(mjc)(Ver: 02.02.05) 
--|   -> UpdFix: Prevee falla de consistencia xApDocRetencion y ApTranRetencion donde DocType<>ApDoc.DocType de los cbtes
--| (CODE)(2012-10-30)(mjc)(Ver: 02.02.04) <-> (Ver: 02.02.01)
--|   -> UpdFix: Neteo de comprobantes en Calculo por Comprobante 
--|   -> BugFix: Multiplic x Factor en RetencionCalculada2  
--| (CODE)(2012-09-19)(mjc)(Ver: 02.02.00) 
--|   -> UpdFix: Retenciones proporcionales a Retencion tipo: Retiene X Documento 
--| (CODE)(2012-08-01)(mjc)(Ver: 02.01.00) 
--|   -> UpdFix: Se agrega la funcionalidad de que el usuario establezca las bases imponibles de manera manual. En cuyo caso 
--|              lo que el usuario agrega es prioritario y prevalece al resto de los inserts en xRetencionDet
--|              Las retenciones manuales se activan con el parametro xApSetup.S4Future11 = '1'
--|   -> UpdFix: Modo DEBUG mejorado para seguimiento % liberaciones y rectificadas
--| (CODE)(2012-07-25)(mjc)(Ver: 02.00.21) 
--|   -> BugFix: Marcar erroneamente una retencion con Ok si el Max(RecordId) es una NC - Contempla OP con solo ND (AC) y NC (AD)
--| (CODE)(2012-07-23)(mjc)(Ver: 02.00.20) 
--|   -> BugFix: Marcar erroneamente una retencion con Ok si el Max(RecordId) es una NC
--| (CODE)(2012-06-13)(mjc)(Ver: 02.00.19) 
--|   -> BugFix: Correccion INNER JOIN con xApRetHist
--| (CODE)(2011-12-23)(mjc)(Ver: 02.00.18) 
--|   -> BugFix: Calculo de Retenciones Negativas
--| (CODE)(2011-10-03)(mjc)(Ver: 02.00.17b) 
--|   -> BugFix: PerPost de la retencion es heredada desde Batch
--| (CODE)(2011-09-30)(mjc)(Ver: 02.00.17) 
--|   -> UpdFix: Se numeran las lineas del xApValPM (LineId, LineNbr)
--| (CODE)(2011-Sep-01)(mjc)(Ver: 02.00.16) 
--|   -> UpdFix: Control de version paso al campo xApValPM.S4Future02
--|   -> UpdFix: Control pseudo calculo previo al calculo final.
--| (CODE)(2011-May-17)(mjc)(Ver: 02.00.15) 
--|   -> UpdFix: Toma en cuenta UserId = 'OPGEN' y no retorna 'PROCESO COMPLETADO' para el generador de OP
--| (CODE)(2010-Dic-22)(m.e.a)(Ver: 02.00.14) 
--|   -> UpdFix: En la insercion de las retenciones en xApValPM el monto del valor se redondea a dos decimales, para evitar que cuando 
--|              se genere el asiento este quede desbalanceado
--|   -> UpdFix: Expone Debug Mode
--| (CODE)(2010-Nov-05)(mjc)(Ver: 02.00.13)
--|   -> BugFix: Proveedor con Retenciones Especiales que no retuviese por las especiales, descartaba el resto de las mismas
--| (CODE)(2010-Sep-06)(mjc)(Ver: 02.00.12f)
--|   -> UpdFix: Retencion 4ta Categ: No descontaba las retenciones sufridas en el periodo
--|   -> UpdFix: Retencion 4ta Categ: Si el monto daba exacto con algún rango se ignoraba (> o <) ahora (> o <=)
--| (CODE)(2010-Ago-11)(mjc)(Ver: 02.00.12e)
--|   -> UpdFix: RetencionCalculada: en la verificacion toma en cuenta el factor. Pero se quita el factor del calculo en si 
--|              ya que BaseCalculoAcum ya viene con el signo correspondiente al tipo de documento
--|   -> BugFix: Se corrige el cálculo de la alicuota rectificada
--|   -> UpdFix: Alicuota rectificada. La alicuota reemplaza a la del padron.
--|   -> UpdFix: Alicuota rectificada y liberaciones. Se utiliza el campo S4Future02 para aclarar rectificaciones y liberaciones.
--|   -> UpdFix: No discrimina comprobantes internos.
--| (CODE)(2010-Ago-10)(mjc)(Ver: 02.00.12d)
--|   -> UpdFix: Ajuste base BaseCalculoAcum (corrije: 02.00.12a)
--| (CODE)(2010-Ago-09)(mjc)(Ver: 02.00.12c)
--|   -> UpdFix: Gan 4ta categoría: Acumula los pagos de la OP 4ta categ
--| (CODE)(2010-Ago-09)(mjc)(Ver: 02.00.12b)
--|   -> UpdFix: Gan 4ta categoría: Filtra para las retenciones que competen esa OP
--| (CODE)(2010-Ago-06)(mjc)(Ver: 02.00.12a)
--|   -> UpdFix: El factor ajusta la BaseCalculoAcum
--| (CODE)(2010-Ene-19)(mjc)(Ver: 02.00.12)
--|   -> UpdFix: Se agrega la funcionalidad de la Alicuota Rectificada como último paso (predomina sobre las demás
--|              definiciones de Alicuotas (padrones) y liberaciones
--| (CODE)(2009-Oct-16)(mjc)(Ver: 02.00.11)
--|   -> BugFix: Si en el padrón venía valor alicuota 0, la ignoraba
--| (CODE)(2009-Ago-11)(mjc)(Ver: 02.00.10)
--|   -> BugFix: Retorno de la Base Imponible en xApValPM
--| (CODE)(2009-Ago-11)(mjc)(Ver: 02.00.09)
--|   -> BugFix: Ajustes varios
--| (CODE)(2009-Ago-10)(mjc)(Ver: 02.00.08)
--|   -> Atencion!!!: con esta version se cambiaron las correcciones correspondientes a las versiones (02.00.05/06/07)
--|   -> BugFix: Utilizacion de parámetros > Retiene X FC: Se modificó el acumulador por línea
--|   -> BugFix: Verifica que no se pueda retener por mas de una vez el total a una FC (Vw_Ap_Tax_DocsFullRet)
--|              (simil (Ver: 02.00.07))
--|   -> UpdFix: Marca CertifXFC genera lineas por cada certificado en xApValPM, de tal manera que se numeren solas
--| (CODE)(2009-Jul-22)(cas)(Ver: 02.00.07) (modif)
--|   -> BugFix: Cuando se inserta en xRetencionDet se verifica que el cbte no haya sido ya tomado 
--|              completamente en el calculo de la retención
--| (CODE)(2009-Jul-21)(cas)(Ver: 02.00.06) (modif)
--|   -> BugFix: La Base de calculo se registra de acuerdo al proporcional pagado. 
--|              De este modo el montopagado se registra correctamente en el xaprethist
--| (CODE)(2009-Jul-20)(mea/cas)(Ver: 02.00.05) (modif)
--|   -> BugFix: Los cptos que no acumulan mensualmente toman el importe total de los cbtes para realizar la ret.
--|		         El proppago es = a 1. La base de calculo se distribuye por cada linea (ya descontando el min no imponible)
--|		         La retencioncalculada también es distribuida. La retencioncalculada2 y el OK = 1 solo se registra para el
--|		         mayor recordid de linea, agrupando x Tipo, Cpto e invcnbr.
--| (CODE)(2009-Jul-17)(mjc)(Ver: 02.00.04) 
--|   -> UpgFix: Se agregaron datos del documento para las retenciones x linea
--|   -> UpgFix: Numero de retencion actualizado
--|   -> BugFix: Calculo correcto de proporciones de pago
--| (CODE)(2009-Jul-16)(mjc)(Ver: 02.00.03) 
--|   -> UpgFix: Se modificó el nombre de la tabla de retenciones de xWrkRetencion a xRetencionDet
--| (CODE)(2009-Jul-14)(mjc)(Ver: 02.00.02) 
--|   -> BugFix: No almacenaba base imponible ni alicuota en xApValPM
--| ...............................................................................................................
--|
ALTER PROCEDURE [dbo].[Spx_AP_Retenciones]
----|
	@zBatNbr			VARCHAR(10),        --> BatNbr de la OP
	@zUserId			VARCHAR(10),		--> Usuario que generó la OP
	@BugMode			BIT = 0
----|

--| ATENCION Para SL 7 
WITH EXECUTE AS '07718158D19D4f5f9D23B55DBF5DF1' 

AS

--| ------------------------------------------------------------------------------------------------------------
--|   ____               _                           _                __     __
--|  |  _ \   ___   ___ | |  __ _  _ __  __ _   ___ (_)  ___   _ __   \ \   / /__ _  _ __  ___
--|  | | | | / _ \ / __|| | / _` || '__|/ _` | / __|| | / _ \ | '_ \   \ \ / // _` || '__|/ __|
--|  | |_| ||  __/| (__ | || (_| || |  | (_| || (__ | || (_) || | | |   \ V /| (_| || |   \__ \
--|  |____/  \___| \___||_| \__,_||_|   \__,_| \___||_| \___/ |_| |_|    \_/  \__,_||_|   |___/
--
--|
--| (PASO 1)
--|
--| Control de Version
--|
DECLARE @zVersion           VARCHAR(30)  
SELECT  @zVersion  = 'Ap Tax Engine: ' + '02.02.20'  -->> ATENCIÓN Actualizar Version!!!!!
--|
--| Declaracion de Variables
--|
DECLARE @iDebug				BIT					--> On/Off del Modo Debug
DECLARE @zSQL				VARCHAR(2000)		--> SQL String de ejecucion
DECLARE @zTiposRetValidos	VARCHAR(  50)		--> Tipos Válidos de retencion
DECLARE @zAllRetValidas     VARCHAR(2000)       --> Todas las combinaciones posibles
DECLARE @zRetSetupAll		VARCHAR(2000)		--> Retorno generico de los parámetros dinámicos
DECLARE @zErrMsg			VARCHAR( 100)		--> Mensaje de error
DECLARE @iErrCtrl			SMALLINT			--> Control de Errores
DECLARE @zCpnyId			VARCHAR(  10)		--> CpnyId de la OP
DECLARE @zVendId			VARCHAR(  15)		--> Codigo de Proveedor de la OP
DECLARE @zFecharPago		SMALLDATETIME		--> Fecha de Pago
DECLARE @zCUITCompania      VARCHAR(  11)       --> CUIT de la compania pagadora
DECLARE @Session			VARCHAR(  50)		--> Session de proceso
--|
--| Variables Auxiliares e internas
--| 
DECLARE @iCount01			INT					--> Variable de conteos varios
DECLARE @iHasta01			INT					--> Variable de control tope de conteos
--|
--| Flags
--|
DECLARE @iConNeteo			BIT					--> On/Off Si los documentos se netean previo cálculo de retenciones
DECLARE @iCpnyRetencion		BIT					--> On/Off si la compañía es agente de retencion de algun tipo de retencion (CLASE I)
DECLARE @iCpnyRetencionBk	BIT					--> On/Off si la compañía es agente de retencion de algun tipo de retencion (CLASE I)
DECLARE @iProvRetencion		BIT					--> On/Off si el proveedor es vulnerable a alguna retencion de algun tipo (CLASE II)
DECLARE @iRetEspeciales		BIT					--> On/Off si las retenciones especiales (caprichosas) estan o no activas (CLASE II)
DECLARE @iRet_EspFut_01		BIT					--> On/Off si las retenciones especiales Futuras (caprichosas) estan o no activas (CLASE II)
DECLARE @iRet_EspFut_02		BIT					--> On/Off si las retenciones especiales Futuras (caprichosas) estan o no activas (CLASE II)
DECLARE @iRet_EspFut_03		BIT					--> On/Off si las retenciones especiales Futuras (caprichosas) estan o no activas (CLASE II)
DECLARE @iRet_EspFut_04		BIT					--> On/Off si las retenciones especiales Futuras (caprichosas) estan o no activas (CLASE II)
DECLARE @iHay4taCateg		BIT					--> On/Off Si tiene alguna retencion de 4ta Categoria (o similares)
DECLARE @iRetManuales		BIT					--> On/Off Si se trabaja con retenciones manuales (Usuario indica en xApDocRetencion base imponible)
--|
--| Inicializacion y Defaults
--|
SET @zTiposRetValidos = ''
SET @zRetSetupAll     = ''
SET @zAllRetValidas   = ''
SET @zErrMsg          = ''
SET @zCpnyId		  = ''
SET @zVendId		  = '' 
SET @zSQL             = ''
SET @zCUITCompania    = ''
SET @Session          = ''
--|
SET @iErrCtrl         = 0
SET @iConNeteo        = 0
SET @iCpnyRetencion   = 0						--> Default False
SET @iCpnyRetencionBk = 0						--> Default False
SET @iProvRetencion   = 0						--> Default False
SET @iRetEspeciales   = 0						--> Default False
SET @iRet_EspFut_01   = 0						--> Default False
SET @iRet_EspFut_02   = 0						--> Default False
SET @iRet_EspFut_03   = 0						--> Default False
SET @iRet_EspFut_04   = 0						--> Default False
SET @iHay4taCateg     = 0						--> Default False
SET @iRetManuales     = 0                       --> Default False
SET @iDebug           = @BugMode				--> Default False
--|
SET @iCount01         = 0
SET @iHasta01         = 0

--|
--| SETs
--|
SET NOCOUNT ON

--|
--| Session
--|
SET @Session = LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(30),GETDATE(),120),'-',''),':',''),' ','_') + '_' + RTRIM(HOST_ID()) + '_' + HOST_NAME(),50)

--|
--| Verifica el modo Debug
--| 
IF @zUserId = 'Debug' SET @iDebug = 1		--> Modo Debug Activado
IF @iDebug = 1 BEGIN
----|
	PRINT '>'
	PRINT '> >>> Modo Debug Activado <<<'
	PRINT '> >>> Session: ' + @Session
	PRINT '> >>> ' + @zVersion
	PRINT '>'
----|
END

--| ------------------------------------------------------------------------------------------------------------
--|   ____          _                 ___   ____
--|  |  _ \   __ _ | |_  ___   ___   / _ \ |  _ \
--|  | | | | / _` || __|/ _ \ / __| | | | || |_) |
--|  | |_| || (_| || |_| (_) |\__ \ | |_| ||  __/
--|  |____/  \__,_| \__|\___/ |___/  \___/ |_|
--
--| (PASO 2) 
--|
--| Datos necesarios de la OP
--|
SELECT 
	@zCpnyId       = ISNULL(xApDocPagoMan.CpnyId,'') , 
	@zVendId       = ISNULL(xApDocPagoMan.VendId,'') ,
	@zFecharPago   = ISNULL(DocDate,GETDATE())       ,
	@zCUITCompania = ISNULL(NroCUIT,'') 
FROM dbo.xApDocPagoMan WITH (NoLock)
INNER JOIN dbo.Batch      WITH (NoLock) ON Batch.BatNbr = xApDocPagoMan.BatNbr AND Batch.Module = 'AP'
INNER JOIN dbo.xCompania  WITH (NoLock) ON xCompania.CpnyId = Batch.CpnyId
AND Batch.Rlsed = 0
AND xApDocPagoMan.BatNbr = @zBatNbr
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Datos OP.'
	SET @iErrCtrl = 0005
	GOTO OutError
END
--|
IF RTRIM(@zCpnyId) = '' OR RTRIM(@zVendId) = '' BEGIN
	IF @iDebug = 1 SELECT @zCpnyId AS CpnyId, @zVendId AS VendId
	SET @zErrMsg  = 'Error: OP sin grabar.'
	SET @iErrCtrl = 0006
	GOTO OutError
END

--|
--| Elimino Retenciones Calculadas anteriormente por este proceso
--|
DELETE X
FROM xApValPM X
INNER JOIN xTipoRetencion WITH (NoLock) ON xTipoRetencion.IdTipoRetencion = X.TipoValorID
WHERE X.BatNbr = @zBatNbr
--|
DELETE FROM dbo.xRetencionDet WHERE OpBatNbr = @zBatNbr
--|
DELETE FROM dbo.XPrintDetPago WHERE BatNbr = @zBatNbr
--|
DELETE X 
FROM dbo.xAPResumenValores X
INNER JOIN xTipoRetencion WITH (NoLock) ON xTipoRetencion.IdTipoRetencion = X.TipoValorID
--|

--| ------------------------------------------------------------------------------------------------------------
--|   ____                                            ____                     _
--|  |  _ \  _ __  ___    ___  ___  ___   ___   ___  |  _ \  _ __  ___ __   __(_)  ___   ___
--|  | |_) || '__|/ _ \  / __|/ _ \/ __| / _ \ / __| | |_) || '__|/ _ \\ \ / /| | / _ \ / __|
--|  |  __/ | |  | (_) || (__|  __/\__ \| (_) |\__ \ |  __/ | |  |  __/ \ V / | || (_) |\__ \
--|  |_|    |_|   \___/  \___|\___||___/ \___/ |___/ |_|    |_|   \___|  \_/  |_| \___/ |___/
--
--| (PASO 3)
--|
--| Tipos de Retencion Autorizadas
--|
SET @zTiposRetValidos = '//'
SELECT @zTiposRetValidos = @zTiposRetValidos + LTRIM(RTRIM(IdTipoRetencion)) + '//' FROM xTipoRetencion WITH (NoLock)
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Tipos Retencion.'
	SET @iErrCtrl = 0010
	GOTO OutError
END
IF @iDebug = 1 PRINT '>> Tipos de Retencion Autorizadas: ' + @zTiposRetValidos + CHAR(13)

--|
--| Muestra los tipos de retención activos para la compañía (DEBUG)
--|
IF @iDebug = 1 BEGIN
----|
	SELECT 'Retenciones Activas en CpnyId' AS Data, * 
	FROM dbo.xCpnyReten WITH (NoLock)
	WHERE CpnyId = @zCpnyId
	AND Activo = 1
	AND FechaInicio <= GETDATE()
	AND PATINDEX( '%' + LTRIM(RTRIM(IdTipoRetencion)) + '%', @zTiposRetValidos) > 0
----|
END

--|
--| Carga las combinaciones activas de Tipo Retencion y Concepto 
--| para cada Tipo de Retencion autorizada
--|
SELECT @zAllRetValidas = @zAllRetValidas + ( LTRIM(RTRIM(xCptoRetencion.IdTipoRetencion)) + LTRIM(RTRIM(xCptoRetencion.IdCptoRetencion)) ) + ':'
FROM dbo.xCptoRetencion WITH (NoLock) 
WHERE PATINDEX( '%' + LTRIM(RTRIM(xCptoRetencion.IdTipoRetencion)) + '%', @zTiposRetValidos) > 0
AND xCptoRetencion.Activo = 1
IF @iDebug = 1 SET @zAllRetValidas = @zAllRetValidas + '/DEBUG/'
--|
SET @zAllRetValidas   = LTRIM(RTRIM(@zAllRetValidas))
IF @iDebug = 1 PRINT '>> Tipo Retencion y Conceptos: (' + CAST(LEN(@zAllRetValidas) AS VARCHAR(10)) + ') ' + RTRIM(@zAllRetValidas) + CHAR(13)

--|
--| Prende o apaga el Flag de Company es Agente de alguna retencion
--| 
IF	(SELECT COUNT(*) FROM xCpnyReten WITH (NoLock) WHERE CpnyId = @zCpnyId AND Activo = 1 AND FechaInicio <= GETDATE() AND PATINDEX( '%' + LTRIM(RTRIM(IdTipoRetencion)) + '%', @zTiposRetValidos) > 0 ) > 0 BEGIN
----|
	SET @iCpnyRetencion   = 1
	SET @iCpnyRetencionBk = 1	
	IF @iDebug = 1 PRINT '>> La CpnyId: ' + RTRIM(@zCpnyId) + ' es Agente de Retención.' + CHAR(13)
----|
END

--|
--| Prende o apaga el Flag de Proveedor vulnerable a retencion
--| 
EXEC dbo.Spx_SetupAll 'RetencionEspeciales', @zRetSetupAll OUTPUT
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Parametros Dinamicos.'
	SET @iErrCtrl = 0011
	GOTO OutError
END
IF @iDebug = 1 PRINT '>> Retenciones Especiales: ' + @zRetSetupAll + CHAR(13)

--|
--| Se activan las retenciones especiales
--|
IF @zRetSetupAll = 'Si' SET @iRetEspeciales = 1
SET @zRetSetupAll = ''

--|
--| Cargo las verificaciones especiales de Retencion
--| Este bloque On/Off de los FLAGS especiales que son de dificil parametrizacion
--|
IF @iRetEspeciales = 1 BEGIN
	--|
	--| Pongo en cero el Flag para tenerlo disponible nuevamente
	--|
	SET @iRetEspeciales = 0
	EXEC spx_OnOffFlagRetencion @zBatNbr, @zVendId, @iProvRetencion OUTPUT, @iRetEspeciales OUTPUT, @zAllRetValidas OUTPUT
	IF @@ERROR <> 0 BEGIN
		SET @zErrMsg  = 'Error: Sp Flag Especial.'
		SET @iErrCtrl = 0020
		GOTO OutError
	END
	IF @iDebug = 1 PRINT '>> Retenciones especiales Flag 1: ' + CASE @iProvRetencion WHEN 1 THEN 'Yes' ELSE 'No ' END + CHAR(13)
	IF @iDebug = 1 PRINT '>> Retenciones especiales Flag 2: ' + CASE @iRetEspeciales WHEN 1 THEN 'Yes' ELSE 'No ' END + CHAR(13)
	IF @iDebug = 1 PRINT '>> Filtro de Retenciones: ' + @zAllRetValidas + CHAR(13)
	--|
	IF @iProvRetencion = 1 AND @iRetEspeciales = 0 BEGIN
		--|
		--| Apago Retenciones Especiales para esta OP
		--| Ya que el proveedor es Monotributista o Adherido al regimen simplificado
		--| pero no cumple ninguna de las condiciones necesarias para ser retenido
		--|
		SET @iCpnyRetencion = @iCpnyRetencionBk
		SET @iProvRetencion = 0
		--|
	END
	
	--|
	--| Agrego al retorno de las retenciones especiales las retenciones NO especiales del proveedor (02.00.13)
	--|
	SELECT @zAllRetValidas = LTRIM(RTRIM(@zAllRetValidas)) + LTRIM(RTRIM(ISNULL(xCptoRetencion.IdTipoRetencion,''))) +  LTRIM(RTRIM(ISNULL(xCptoRetencion.IdCptoRetencion,''))) + ':'
	FROM dbo.xVendorRetencion     WITH (NoLock)
	INNER JOIN dbo.xCptoRetencion WITH (NoLock) ON xCptoRetencion.IdTipoRetencion = xVendorRetencion.IdTipoRetencion AND xCptoRetencion.IdCptoRetencion = xVendorRetencion.IdCptoRet
	LEFT  JOIN dbo.xPlazoAcumTax  WITH (NoLock) ON xPlazoAcumTax.IdPlazoTax = xCptoRetencion.IdPlazoTax
	WHERE xVendorRetencion.Activo = 1
	AND xVendorRetencion.VendId = @zVendId
	AND xCptoRetencion.Activo   = 1
	AND xPlazoAcumTax.IdPlazoTax IS NULL
	
	IF @iDebug = 1 SET @zAllRetValidas = @zAllRetValidas + '/DEBUG/'
	IF @iDebug = 1 PRINT '>> Filtro de Retenciones (Luego de Especiales) Add Standard: ' + @zAllRetValidas + CHAR(13)
	
END

--|
--| Si Ninguno de los flags se prendió es por que no hay que realizar ninguna retención.
--|
IF @iCpnyRetencion = 0 AND @iProvRetencion = 0 BEGIN
	GOTO OutOk   --> No es necesario calcular nada.
END

--|
--| Verifico si poseen Retenciones manuales. De ser positivo, o sea, en la OP se calculan Retenciones Manuales
--| Se desactivan las retenciones por Documento y por Linea
--|
SELECT @iRetManuales = CASE WHEN S4Future11 = '1' THEN 1 ELSE 0 END FROM dbo.xAPSetup WITH (NoLock) 
IF @iDebug = 1 BEGIN
	IF @iRetManuales = 1 
		PRINT '>> Retenciones MANUALES |ACTIVAS|'
	ELSE               
		PRINT '>> Retenciones MANUALES |Inactivas|'
END

--| 
--| Preveo posibles problemas de consistencia (muchas veces xApDocRetencion y/o xApTranRetencion
--| cuando fueron editados posteriormente generan una pequeña inconsistencia de DocType/TranType
--|
UPDATE x SET
	x.DocType = A.DocType
FROM xAPDocRetencion x
INNER JOIN APDoc A WITH (NoLock) ON A.RecordID = x.RecordId AND A.BatNbr = x.BatNbr AND A.RefNbr = x.RefNbr
INNER JOIN xAPCbtesPagoMan P WITH (NoLock) ON P.RefNbr = A.RefNbr AND P.DocType = A.DocType AND P.VendId = A.VendId
WHERE P.BatNbr = @zBatNbr
AND x.DocType <> A.DocType
--|
UPDATE x SET
	x.TranType = A.DocType
FROM xApTranRetencion x
INNER JOIN APDoc A WITH (NoLock) ON A.RecordID = x.APDocRecordId AND A.BatNbr = x.BatNbr AND A.RefNbr = x.RefNbr
INNER JOIN xAPCbtesPagoMan P WITH (NoLock) ON P.RefNbr = A.RefNbr AND P.DocType = A.DocType AND P.VendId = A.VendId
WHERE P.BatNbr = @zBatNbr
AND x.TranType <> A.DocType
--|
UPDATE x SET
	BasRet = (x.CuryBasRet * A.CuryRate)
FROM xAPDocRetencion x
INNER JOIN APDoc A WITH (NoLock) ON A.RecordID = x.RecordId AND A.BatNbr = x.BatNbr AND A.RefNbr = x.RefNbr
INNER JOIN xAPCbtesPagoMan P WITH (NoLock) ON P.RefNbr = A.RefNbr AND P.DocType = A.DocType AND P.VendId = A.VendId
WHERE P.BatNbr = @zBatNbr
AND CONVERT(NUMERIC(15,4),x.BasRet) <> CONVERT(NUMERIC(15,4),(x.CuryBasRet * A.CuryRate))

--| Si las retenciones son manuales y el doc a pagar es cuota, verifica la Base Retenible
IF @iRetManuales = 1 BEGIN
	EXEC Spx_BaseRetencionCuota @zBatNbr
END

--|
--|
--| ------------------------------------------------------------------------------------------------------------
--|            ____   __   _               _          ____        _                      _    __
--|           / ___| /_/_ | |  ___  _   _ | |  ___   |  _ \  ___ | |_  ___  _ __    ___ (_)  /_/   _ __
--|          | |    / _` || | / __|| | | || | / _ \  | |_) |/ _ \| __|/ _ \| '_ \  / __|| | / _ \ | '_ \
--|          | |___| (_| || || (__ | |_| || || (_) | |  _ <|  __/| |_|  __/| | | || (__ | || (_) || | | |
--|           \____|\__,_||_|_\___| \__,_||_| \___/  |_| \_\\___| \__|\___||_| |_| \___||_| \___/ |_| |_|
--|                         |  _ \   ___    ___  _   _  _ __ ___    ___  _ __  | |_  ___
--|                         | | | | / _ \  / __|| | | || '_ ` _ \  / _ \| '_ \ | __|/ _ \
--|                         | |_| || (_) || (__ | |_| || | | | | ||  __/| | | || |_| (_) |
--|                         |____/  \___/  \___| \__,_||_| |_| |_| \___||_| |_| \__|\___/
--|
IF @iDebug = 1 PRINT '>> CALCULANDO Documento Manuales...'
--|
--| (PASO 4a)
--| .:Retenciones a Nivel Documento:.
--|   > Trae los datos para las retenciones a nivel de documento de los comprobantes asociados a la OP.
--|     Se basa en las vistas Vw_Ap_ApDocTax_End_Man >> Vw_Ap_ApDocTax_x_Doc_Man >> Vw_Ap_ApDocTax_Man.
--|   > Vw_Ap_ApDocTax_Man: Descompone los documentos de AP desde ApTran Según sus categorías (TaxCat y TranClass)
--|   >> Vw_Ap_ApDocTax_x_Doc_Man: Relaciona las lineas de Vw_Ap_ApDocTax con las retenciones
--|   >>> Vw_Ap_ApDocTax_End_Man: Sumariza y agrupa por las retenciones que le corresponden (pero sin calcular aun nada)
--|   > Siempre Filtrando para las retenciones activas y para la OP
--|   > El resultado se almacena en la tabla xRetencionDet
--|    
INSERT INTO dbo.xRetencionDet
	(
	OpBatNbr, NroOPago, PerPost, TranDate, CpnyId, CpnyCUIT,
	BatNbr, RefNbr, DocType, VendId, ApDocRecordId, ApTranRecordId, 
	InvcNbr, JurID, TipoConvId, TDocDGIID, NroCUIT, 
	Grabado, NoGrabado, Exento, Sellos, Tax, Descuentos, Neto, Bruto, OrigDocAmt, PmtAmt, IdTipoRetencion, 
	IdCptoRetencion, PropPago, TranAmt, BaseCalculo, BaseCalculoAcum, BaseCalculoDesc, MontoPagado, MontoRetenido, AcumulaMensual, 
	RetieneXFC, CertifXFC, IdPadron, 
	AlicuotaPadron, Alicuota, LimiteSup, ImporteBase, ImporteExced, RetencionMinima, MinNoImponible, NetoASuperar, BrutoASuperar, NetoAcumASuperar, 
	BrutoAcumASuperar, IdPlazoTax, PrecioUnit,  RetencionCalculada, RetencionCalculada2, RetencionCalculadaDesc, 
	Factor, Liberacion, BaseAplic, Status, Ok, 
	VendorDes, NroRetencion, DescTipoRet, DescConcRet, IdCont,
	S4Future01, -->> Control de Version
	Session
	)
SELECT 
	v.OpBatNbr, v.NroOPago, v.PerPost, v.DocDate, @zCpnyId, @zCUITCompania,
	v.BatNbr, v.RefNbr, v.DocType, v.VendId, v.RecordId, 0, 
	v.InvcNbr, v.JurID, v.TipoConvId, v.TDocDGIID, v.NroCUIT, 
	v.Grabado, v.NoGrabado, v.Exento, v.Sellos, v.Tax, v.Descuentos, v.Neto, v.Bruto, v.OrigDocAmt, v.PmtAmt, v.IdTipoRetencion, 
	v.IdCptoRetencion, v.PropPago, v.TranAmt, v.BaseCalculo, 0 AS BaseCalculoAcum, 0 AS BaseCalculoDec, v.MontoPagado, v.MontoRetenido, 
	v.AcumulaMensual, v.RetieneXFC, v.CertifXFC, v.IdPadron, 
	v.AlicuotaPadron, v.Alicuota, v.LimiteSup, v.ImporteBase, v.ImporteExced, v.RetencionMinima, 
	v.MinNoImponible, v.NetoASuperar, v.BrutoASuperar, v.NetoAcumASuperar, 
	v.BrutoAcumASuperar, v.IdPlazoTax, v.PrecioUnit, 
	0 AS RetencionCalculada, 0 AS RetencionCalculada2, 0 AS RetencionCalculadaDesc, v.Factor, 0, 'M', '', 0, 
	/*VendorDes*/'', /*NroRetencion*/'', /*DescTipoRet*/'', /*DescConcRet*/'', /*IdCont*/'',
	@zVersion,
	@Session
FROM dbo.Vw_Ap_ApDocTax_End_Man v
LEFT  JOIN dbo.Vw_Ap_Tax_DocsFullRet W ON W.RefNbr = v.RefNbr AND W.DocType = v.DocType AND W.ApDocRecordId = v.RecordId AND W.IdTipoRetencion = v.IdTipoRetencion AND W.IdCptoRetencion = v.IdCptoRetencion
WHERE v.OpBatNbr = @zBatNbr
AND PATINDEX( '%' + LTRIM(RTRIM(v.IdTipoRetencion)) + LTRIM(RTRIM(v.IdCptoRetencion)) + '%', @zAllRetValidas) > 0
AND W.ApDocRecordId IS NULL
AND @iRetManuales = 1                   --> Retenciones manuales activas = 1
ORDER BY 
	v.IdTipoRetencion, v.IdCptoRetencion, 
	CASE v.DocType WHEN 'AD' THEN 1 WHEN 'AC' THEN 2 WHEN 'VO' THEN 3 END, 
	v.BatNbr
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Retencion Manual x Documento.'
	SET @iErrCtrl = 0031
	GOTO OutError
END
IF @iDebug = 1 SELECT  '>> Retenciones Manuales x Docs: ' AS Tipo, * FROM dbo.xRetencionDet WITH (NoLock) WHERE Session = @Session AND BaseAplic = 'M' AND @iRetManuales = 1

--|
IF @iDebug = 1 PRINT '>> CALCULANDO Documento...'
--|
--| (PASO 4b)
--| .:Retenciones a Nivel Documento:.
--|   > Trae los datos para las retenciones a nivel de documento de los comprobantes asociados a la OP.
--|     Se basa en las vistas Vw_Ap_ApDocTax_End >> Vw_Ap_ApDocTax_x_Doc >> Vw_Ap_ApDocTax.
--|   > Vw_Ap_ApDocTax: Descompone los documentos de AP desde ApTran Según sus categorías (TaxCat y TranClass)
--|   >> Vw_Ap_ApDocTax_x_Doc: Relaciona las lineas de Vw_Ap_ApDocTax con las retenciones
--|   >>> Vw_Ap_ApDocTax_End: Sumariza y agrupa por las retenciones que le corresponden (pero sin calcular aun nada)
--|   > Siempre Filtrando para las retenciones activas y para la OP
--|   > El resultado se almacena en la tabla xRetencionDet
--|    
INSERT INTO dbo.xRetencionDet
	(
	OpBatNbr, NroOPago, PerPost, TranDate, CpnyId, CpnyCUIT,
	BatNbr, RefNbr, DocType, VendId, ApDocRecordId, ApTranRecordId, 
	InvcNbr, JurID, TipoConvId, TDocDGIID, NroCUIT, 
	Grabado, NoGrabado, Exento, Sellos, Tax, Descuentos, Neto, Bruto, OrigDocAmt, PmtAmt, IdTipoRetencion, 
	IdCptoRetencion, PropPago, TranAmt, BaseCalculo, BaseCalculoAcum, BaseCalculoDesc, MontoPagado, MontoRetenido, AcumulaMensual, 
	RetieneXFC, CertifXFC, IdPadron, 
	AlicuotaPadron, Alicuota, LimiteSup, ImporteBase, ImporteExced, RetencionMinima, MinNoImponible, NetoASuperar, BrutoASuperar, NetoAcumASuperar, 
	BrutoAcumASuperar, IdPlazoTax, PrecioUnit,  RetencionCalculada, RetencionCalculada2, RetencionCalculadaDesc, 
	Factor, Liberacion, BaseAplic, Status, Ok, 
	VendorDes, NroRetencion, DescTipoRet, DescConcRet, IdCont,
	S4Future01, -->> Control de Version
	Session
	)
SELECT 
	v.OpBatNbr, v.NroOPago, v.PerPost, v.DocDate, @zCpnyId, @zCUITCompania,
	v.BatNbr, v.RefNbr, v.DocType, v.VendId, v.RecordId, 0, 
	v.InvcNbr, v.JurID, v.TipoConvId, v.TDocDGIID, v.NroCUIT, 
	v.Grabado, v.NoGrabado, v.Exento, v.Sellos, v.Tax, v.Descuentos, v.Neto, v.Bruto, v.OrigDocAmt, v.PmtAmt, v.IdTipoRetencion, 
	v.IdCptoRetencion, v.PropPago, v.TranAmt, v.BaseCalculo, 0 AS BaseCalculoAcum, 0 AS BaseCalculoDec, v.MontoPagado, v.MontoRetenido, 
	v.AcumulaMensual, v.RetieneXFC, v.CertifXFC, v.IdPadron, 
	v.AlicuotaPadron, v.Alicuota, v.LimiteSup, v.ImporteBase, v.ImporteExced, v.RetencionMinima, 
	v.MinNoImponible, v.NetoASuperar, v.BrutoASuperar, v.NetoAcumASuperar, 
	v.BrutoAcumASuperar, v.IdPlazoTax, v.PrecioUnit, 
	0 AS RetencionCalculada, 0 AS RetencionCalculada2, 0 AS RetencionCalculadaDesc, v.Factor, 0, 'D', '', 0, 
	/*VendorDes*/'', /*NroRetencion*/'', /*DescTipoRet*/'', /*DescConcRet*/'', /*IdCont*/'',
	@zVersion,
	@Session
FROM dbo.Vw_Ap_ApDocTax_End v
LEFT  JOIN dbo.Vw_Ap_Tax_DocsFullRet W ON W.RefNbr = v.RefNbr AND W.DocType = v.DocType AND W.ApDocRecordId = v.RecordId AND W.IdTipoRetencion = v.IdTipoRetencion AND W.IdCptoRetencion = v.IdCptoRetencion
WHERE v.OpBatNbr = @zBatNbr
AND PATINDEX( '%' + LTRIM(RTRIM(v.IdTipoRetencion)) + LTRIM(RTRIM(v.IdCptoRetencion)) + '%', @zAllRetValidas) > 0
AND W.ApDocRecordId IS NULL
AND @iRetManuales = 0                   --> Retenciones automaticas activas =1
ORDER BY v.IdTipoRetencion, v.IdCptoRetencion, v.BatNbr
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Retencion x Documento.'
	SET @iErrCtrl = 0030
	GOTO OutError
END
IF @iDebug = 1 SELECT  '>> Retenciones x Docs: ' AS Tipo, * FROM dbo.xRetencionDet WITH (NoLock) WHERE Session = @Session AND BaseAplic = 'D' AND @iRetManuales = 0
--|
IF @iDebug = 1 PRINT '>> CALCULANDO Linea...'
--|
--| (PASO 4c)
--| Retenciones a Nivel de Línea
--| Basicamente relaciona las líneas de ApTran con xApTranRetencion para las retenciones cuyo BaseAplic = 'L' (Linea)
--| y los deja en la tabla de calculo de retenciones
--|
INSERT INTO dbo.xRetencionDet
	(
	OpBatNbr, NroOPago, PerPost, TranDate, CpnyId, CpnyCUIT,
	BatNbr, RefNbr, DocType, VendId, ApDocRecordId, ApTranRecordId, 
	InvcNbr, JurID, TipoConvId, TDocDGIID, NroCUIT, 
	Grabado, NoGrabado, Exento, Sellos, Tax, Descuentos, Neto, Bruto, OrigDocAmt, PmtAmt, IdTipoRetencion, 
	IdCptoRetencion, PropPago, TranAmt, BaseCalculo, BaseCalculoAcum, BaseCalculoDesc, MontoPagado, MontoRetenido, AcumulaMensual, 
	RetieneXFC, CertifXFC, IdPadron, 
	AlicuotaPadron, Alicuota, LimiteSup, ImporteBase, ImporteExced, RetencionMinima, MinNoImponible, NetoASuperar, BrutoASuperar, NetoAcumASuperar, 
	BrutoAcumASuperar, IdPlazoTax, PrecioUnit,  RetencionCalculada, RetencionCalculada2, RetencionCalculadaDesc, 
	Factor, Liberacion, BaseAplic, Status, Ok, 
	VendorDes, NroRetencion, DescTipoRet, DescConcRet, IdCont,
	S4Future01, -->> Control de Version
	Session
	)
SELECT --DISTINCT
	xApDocPagoMan.BatNbr, xApDocPagoMan.NroOPago, Batch.PerPost, xApDocPagoMan.DocDate, @zCpnyId, @zCUITCompania,
	ApTran.BatNbr, ApTran.RefNbr, ApTran.TranType, ApTran.VendId, 
	xApTranRetencion.APDocRecordId, xApTranRetencion.RecordId AS ApTranRecordId, 
	ApDoc.InvcNbr, xApDoc.JurID, xProveedor.TConvIIBB AS TipoConvId, xProveedor.TDocDGIID, xProveedor.NroCUIT, 
	0 AS Grabado, 0 AS NoGrabado, 0 AS Exento, 0 AS Sellos, 0 AS Tax, 0 AS Descuentos, 0 AS Neto, 
	ApDoc.OrigDocAmt AS Bruto, ApDoc.OrigDocAmt, xApCbtesPagoMan.PmtAmt, 
	xConceptoRetAlic.IdTipoRetencion, xConceptoRetAlic.IdCptoRetencion, 
	--CASE RetieneXFC WHEN 0 THEN (xApCbtesPagoMan.PmtAmt / ApDoc.OrigDocAmt) ELSE 1 END AS PropPago,
	(xApCbtesPagoMan.PmtAmt / ApDoc.OrigDocAmt) AS PropPago,
	ApTran.TranAmt, ApTran.TranAmt AS BaseCalculo, 0 AS BaseCalculoAcum, 0 AS BaseCalculoDesc, 
	ISNULL(xApRetHist.MontoPagado,0) AS MontoPagado,
	ISNULL(xApRetHist.MontoRetenido,0) AS MontoRetenido, 
	xCptoRetencion.AcumulaMensual, xCptoRetencion.RetieneXFC, xCptoRetencion.CertifXFC, xCptoRetencion.IdPadron, 
	ISNULL(Vw_xAlicIIBBBsAs.Alicuota2,-1) AS AlicuotaPadron,
	xConceptoRetAlic.Alicuota, xConceptoRetAlic.LimiteSup, xConceptoRetAlic.ImporteBase, xConceptoRetAlic.ImporteExced, 
	xCptoRetencion.RetencionMinima, xCptoRetencion.MinNoImponible, xCptoRetencion.NetoASuperar, xCptoRetencion.BrutoASuperar, 
	xCptoRetencion.NetoAcumASuperar, xCptoRetencion.BrutoAcumASuperar,     
	xCptoRetencion.IdPlazoTax, xCptoRetencion.PrecioUnit,  0 AS RetencionCalculada, 0 AS RetencionCalculada2, 0 AS RetencionCalculadaDesc, 
	CASE WHEN ApTran.TranType IN ('VO','AC') THEN 1 ELSE -1 END AS Factor, 
	0 AS Liberacion, xCptoRetencion.BaseAplic, '' AS Status,  0 AS Ok, 
	/*VendorDes*/'', /*NroRetencion*/'', /*DescTipoRet*/'', /*DescConcRet*/'', /*IdCont*/'',
	@zVersion,
	@Session
FROM dbo.xApCbtesPagoMan        WITH (NoLock) 
INNER JOIN dbo.Batch            WITH (NoLock) ON Batch.Module = 'AP' AND Batch.BatNbr = xApCbtesPagoMan.BatNbr
INNER JOIN dbo.xApDocPagoMan    WITH (NoLock) ON xApDocPagoMan.BatNbr = xApCbtesPagoMan.BatNbr
INNER JOIN dbo.ApDoc            WITH (NoLock) ON ApDoc.RefNbr = xApCbtesPagoMan.RefNbr AND ApDoc.DocType = xApCbtesPagoMan.DocType
INNER JOIN dbo.xApDoc           WITH (NoLock) ON xApDoc.RecordId = ApDoc.RecordId AND xApDoc.RefNbr = ApDoc.RefNbr AND xApDoc.DocType = ApDoc.DocType
INNER JOIN dbo.xProveedor       WITH (NoLock) ON xProveedor.VendId = xApCbtesPagoMan.VendId
INNER JOIN dbo.ApTran           WITH (NoLock) ON ApTran.BatNbr = ApDoc.BatNbr AND ApTran.RefNbr = ApDoc.RefNbr AND ApTran.VendId = ApDoc.VendId AND ApTran.TranType = ApDoc.DocType
INNER JOIN dbo.xApTranRetencion WITH (NoLock) ON xApTranRetencion.RecordId = ApTran.RecordId AND xApTranRetencion.APDocRecordId = ApDoc.RecordId AND xApTranRetencion.BatNbr = ApTran.BatNbr AND xApTranRetencion.RefNbr = ApTran.RefNbr AND xApTranRetencion.VendId = ApTran.VendId AND xApTranRetencion.TranType = ApTran.TranType
INNER JOIN dbo.xCptoRetencion   WITH (NoLock) ON xCptoRetencion.IdTipoRetencion = xApTranRetencion.IdTipoRetencion AND xCptoRetencion.IdCptoRetencion = xApTranRetencion.IdCptoRet
INNER JOIN dbo.xConceptoRetAlic WITH (NoLock) ON xConceptoRetAlic.IdTipoRetencion = xCptoRetencion.IdTipoRetencion AND xConceptoRetAlic.IdCptoRetencion = xCptoRetencion.IdCptoRetencion
LEFT  JOIN dbo.xApRetHist       WITH (NoLock) ON xApretHist.TipoRet = xCptoRetencion.IdTipoRetencion AND xApretHist.CptoRet = xCptoRetencion.IdCptoRetencion AND xApretHist.VendId = xApDocPagoMan.VendId AND xApretHist.PerPost = Batch.PerPost
LEFT  JOIN 
	( 
	--[Ver: 02.02.18 - Padrones con CUITs repetidos. VendId diferentes mismo CUIT en FF]
	--[Ver: 02.02.20 - Se incluye el Agente recaudador. Proveedores que figuran en mas de un PADRON
	SELECT 
		PP.RecordId, PP.FechaPublic, PP.FechaDesde, PP.FechaHasta, 
		PP.CUIT, PP.TipoContrib, PP.Alta, PP.CambiaAlicuota, PP.Alicuota, 
		PP.Alicuota2, PP.MesInicio, PP.AnioInicio, PP.User1, PP.User2, 
		PP.User3, PP.User4, PP.User5, PP.User6, PP.User7, PP.User8, 
		PP.AgteRecaudador
	FROM Vw_xAlicIIBBBsAs PP
	INNER JOIN 
		(
		SELECT CUIT, AgteRecaudador, MAX(RecordId) AS RecordId 
		FROM Vw_xAlicIIBBBsAs
		GROUP BY CUIT, AgteRecaudador
		) AS PPU ON PPU.CUIT = PP.CUIT AND PPU.AgteRecaudador = PP.AgteRecaudador AND PPU.RecordId = PP.RecordId
	) Vw_xAlicIIBBBsAs ON '80' = xProveedor.TDocDGIID AND Vw_xAlicIIBBBsAs.CUIT = xProveedor.NroCUIT AND Vw_xAlicIIBBBsAs.AgteRecaudador = xCptoRetencion.IdPadron
LEFT  JOIN dbo.Vw_Ap_Tax_DocsFullRet W   ON W.RefNbr = ApDoc.RefNbr AND W.DocType = ApDoc.DocType AND W.ApDocRecordId = ApDoc.RecordId AND W.IdTipoRetencion = xCptoRetencion.IdTipoRetencion AND W.IdCptoRetencion = xCptoRetencion.IdCptoRetencion
WHERE xCptoRetencion.BaseAplic = 'L'	--> Lineas de Aplicacion
AND ApTran.TranClass <> 'T'             --> Elimino las líneas de impuestos
AND ((ApTran.TranType IN ('VO','AC') AND ApTran.DrCr = 'D') OR (ApTran.TranType IN ('AD','PP') AND ApTran.DrCr = 'C')) --> Tomo las líneas que corresponden
AND Batch.Rlsed = 0                     --> Solo para las OP no liberadas
AND ApDoc.DocType IN ('VO','AD','AC')   --> Unicos documentos retenibles
--| AND xApDoc.TCbteLegalID NOT IN (SELECT TipoCbteInt FROM xApSetup WITH (NoLock) ) --> Que no sean documentos internos
AND xApDocPagoMan.BatNbr = @zBatNbr
AND PATINDEX( '%' + LTRIM(RTRIM(xCptoRetencion.IdTipoRetencion)) + LTRIM(RTRIM(xCptoRetencion.IdCptoRetencion)) + '%', @zAllRetValidas) > 0
AND W.ApDocRecordId IS NULL             --> Retenciones ya calculadas
AND @iRetManuales = 0                   --> Retenciones automaticas activas = 1
ORDER BY CASE ApTran.TranType WHEN 'AD' THEN 'ZZ' ELSE ApTran.TranType END
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Retencion x Linea.'
	SET @iErrCtrl = 0050
	GOTO OutError
END
IF @iDebug = 1 SELECT  '>> Retenciones x Linea: ' AS Tipo, * FROM dbo.xRetencionDet WITH (NoLock) WHERE Session = @Session AND BaseAplic = 'L'
--|
IF @iDebug = 1 SELECT  '>> Retenciones x All: ' AS Tipo, * FROM dbo.xRetencionDet WITH (NoLock) WHERE Session = @Session ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId
--|

--| -----------------------------------------------------------------------------------------------------------------------
--|
--| Completa datos de referencia y similares
--|
IF @iRetManuales = 0  
	UPDATE X SET 
		VendorDes    = ISNULL( V.Name      ,'.(no data).') ,
		DescTipoRet  = ISNULL( T.Descr     ,'.(no data).') ,
		DescConcRet  = ISNULL( C.Descr     ,'.(no data).') ,
		IdCont       = ISNULL( C.NumCbtesId,'.(no data).') ,
		Grabado      = ISNULL( W.Grabado   , 0           ) ,
		NoGrabado    = ISNULL( W.NoGrabado , 0           ) ,
		Exento       = ISNULL( W.Exento    , 0           ) ,
		Sellos       = ISNULL( W.Sellos    , 0           ) ,
		Tax          = ISNULL( W.Tax       , 0           ) ,
		Descuentos   = ISNULL( W.Descuentos, 0           ) ,
		Neto         = ISNULL( W.Neto      , 0           ) 
	FROM dbo.xRetencionDet X
	LEFT JOIN dbo.Vendor           V WITH (NoLock) ON V.VendId = X.VendId
	LEFT JOIN dbo.xTipoRetencion   T WITH (NoLock) ON T.IdTipoRetencion = X.IdTipoRetencion 
	LEFT JOIN dbo.xCptoRetencion   C WITH (NoLock) ON C.IdTipoRetencion = X.IdTipoRetencion AND C.IdCptoRetencion = X.IdCptoRetencion
	LEFT JOIN dbo.vw_Ap_DocTran_Boom W        ON W.CpnyId = X.CpnyId AND W.BatNbr = X.BatNbr AND W.RefNbr = X.RefNbr AND W.TranType = X.DocType AND W.VendId = X.VendId 
	WHERE X.OpBatNbr  = @zBatNbr
	AND   X.Session   = @Session
ELSE
	UPDATE X SET 
		VendorDes    = ISNULL( V.Name      ,'.(no data).') ,
		DescTipoRet  = ISNULL( T.Descr     ,'.(no data).') ,
		DescConcRet  = ISNULL( C.Descr     ,'.(no data).') ,
		IdCont       = ISNULL( C.NumCbtesId,'.(no data).') ,
		Grabado      = ISNULL( W.Grabado   , 0           ) ,
		NoGrabado    = ISNULL( W.NoGrabado , 0           ) ,
		Exento       = ISNULL( W.Exento    , 0           ) ,
		Sellos       = ISNULL( W.Sellos    , 0           ) ,
		Tax          = ISNULL( W.Tax       , 0           ) ,
		Descuentos   = ISNULL( W.Descuentos, 0           ) ,
		Neto         = ISNULL( W.Neto      , 0           ) 
	FROM dbo.xRetencionDet X
	LEFT JOIN dbo.Vendor           V WITH (NoLock) ON V.VendId = X.VendId
	LEFT JOIN dbo.xTipoRetencion   T WITH (NoLock) ON T.IdTipoRetencion = X.IdTipoRetencion 
	LEFT JOIN dbo.xCptoRetencion   C WITH (NoLock) ON C.IdTipoRetencion = X.IdTipoRetencion AND C.IdCptoRetencion = X.IdCptoRetencion
	LEFT JOIN dbo.vw_Ap_DocTran_Boom_Man W    ON W.CpnyId = X.CpnyId AND W.BatNbr = X.BatNbr AND W.RefNbr = X.RefNbr AND W.TranType = X.DocType AND W.VendId = X.VendId 
	WHERE X.OpBatNbr  = @zBatNbr
	AND   X.Session   = @Session


--| ----------------------------------------------------------------------------------------
--| Acumulados por OP y Tipo de retencion (Acumulado linea a linea) ¡¡¡¡NO ES HISTÓRICO!!!!
--| Lo que hace este paso es agrupar (sumarizar) las bases de cálculo de cada comprobante 
--| que pertenece a la OP y que tenga el mismo tipo de retencion y concepto. 
--| Solo sirve si el parámetro RetieneXFC = 1 (Retiene Por Factura)
--| De esta manera va sumarizando la base calculable línea a línea.
--| Ejemplo:
--|| ---------------------------------------------------------------------------------------
--|| BaseCalculo   BaseCalculoAcum
--|| -----------   ---------------
--||      300.00            300.00
--||      500.00            800.00  --> Suma esta línea mas el total de la anterior
--||      200.00          1,000.00  --> Suma esta línea mas el total de la anterior
--||      150,35          1,150.35  --> Suma esta línea mas el total de la anterior (final)
--|| ---------------------------------------------------------------------------------------
--|  ...parece dificil pero solo es complicado y complejo... nada mas...
--| ----------------------------------------------------------------------------------------
UPDATE Q SET
	BaseCalculoAcum = v.BaseCalculoAcum 
FROM dbo.xRetencionDet Q
INNER JOIN 
	(
	SELECT A1.IdTipoRetencion, A1.IdCptoRetencion, A1.BaseAplic, A1.WrkRecordId, A1.BaseCalculo, SUM(ISNULL(A2.BaseCalculo,0)) AS BaseCalculoAcum
	FROM 
		(
		SELECT 
			Z.IdTipoRetencion, Z.IdCptoRetencion, Z.BaseAplic, Z.LimiteSup, Z.WrkRecordId, CASE Z.RetieneXFC WHEN 1 THEN RTRIM(Z.DocType) + RTRIM(Z.RefNbr) ELSE '[ALL]' END AS PorDoc, 
			((Z.BaseCalculo * (CASE WHEN (Z.BaseAplic IN ('L','M') OR Z.RetieneXFC = 1) THEN Z.PropPago ELSE 1 END)) * Z.Factor) AS BaseCalculo
		FROM dbo.xRetencionDet Z WITH (NoLock) 
		INNER JOIN
			(
			SELECT	IdTipoRetencion, IdCptoRetencion, BaseAplic, LimiteSup, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END AS PorDoc,
					MIN(WrkRecordId) AS Alfa, MAX(WrkRecordId) AS Omega
			FROM dbo.xRetencionDet  WITH (NoLock) 
			WHERE Session      = @Session
			AND OpBatNbr       = @zBatNbr
			GROUP BY IdTipoRetencion, IdCptoRetencion, BaseAplic, LimiteSup, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END
			) X ON X.IdTipoRetencion = Z.IdTipoRetencion AND X.IdCptoRetencion = Z.IdCptoRetencion AND X.BaseAplic = Z.BaseAplic AND X.LimiteSup = Z.LimiteSup AND X.PorDoc = CASE Z.RetieneXFC WHEN 1 THEN RTRIM(Z.DocType) + RTRIM(Z.RefNbr) ELSE '[ALL]' END AND Z.WrkRecordId BETWEEN X.Alfa AND X.Omega
		) A1 
	LEFT  JOIN 
		(
		SELECT 
			Z.IdTipoRetencion, Z.IdCptoRetencion, Z.BaseAplic, Z.LimiteSup, Z.WrkRecordId, CASE Z.RetieneXFC WHEN 1 THEN RTRIM(Z.DocType) + RTRIM(Z.RefNbr) ELSE '[ALL]' END AS PorDoc, 
			((ISNULL(Z.BaseCalculo,0) * (CASE WHEN (Z.BaseAplic IN ('L','M') OR Z.RetieneXFC = 1) THEN Z.PropPago ELSE 1 END)) * ISNULL(Z.Factor,1)) AS BaseCalculo
		FROM dbo.xRetencionDet Z WITH (NoLock) 
		INNER JOIN
			(
			SELECT	IdTipoRetencion, IdCptoRetencion, BaseAplic, LimiteSup, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END AS PorDoc,
					MIN(WrkRecordId) AS Alfa, MAX(WrkRecordId) AS Omega
			FROM dbo.xRetencionDet  WITH (NoLock) 
			WHERE Session      = @Session
			AND OpBatNbr       = @zBatNbr
			GROUP BY IdTipoRetencion, IdCptoRetencion, BaseAplic, LimiteSup, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END
			) X ON X.IdTipoRetencion = Z.IdTipoRetencion AND X.IdCptoRetencion = Z.IdCptoRetencion AND X.BaseAplic = Z.BaseAplic AND X.LimiteSup = Z.LimiteSup AND X.PorDoc = CASE Z.RetieneXFC WHEN 1 THEN RTRIM(Z.DocType) + RTRIM(Z.RefNbr) ELSE '[ALL]' END AND Z.WrkRecordId BETWEEN X.Alfa AND X.Omega
		) A2 ON (A2.IdTipoRetencion = A1.IdTipoRetencion AND A2.IdCptoRetencion = A1.IdCptoRetencion AND A2.BaseAplic = A1.BaseAplic AND A2.LimiteSup = A1.LimiteSup) AND (A2.PorDoc = A1.PorDoc) AND (A2.WrkRecordId <= A1.WrkRecordId )
	GROUP BY A1.IdTipoRetencion, A1.IdCptoRetencion, A1.BaseAplic, A1.WrkRecordId, A1.BaseCalculo, A1.LimiteSup
	) v ON v.IdTipoRetencion = Q.IdTipoRetencion AND v.IdCptoRetencion = Q.IdCptoRetencion AND v.BaseAplic = Q.BaseAplic AND v.WrkRecordId = Q.WrkRecordId
--|
IF @iDebug = 1 SELECT  '>> Retenciones Acum: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId

--| ----------------------------------------------------------------------------------------
--|  _  _  ____  ____  ____  _____ 
--| ( \( )( ___)(_  _)( ___)(  _  )
--|  )  (  )__)   )(   )__)  )(_)( 
--| (_)\_)(____) (__) (____)(_____)
--| 
--| Neteo [(CODE)(2012-09-19)(mjc)(Ver: 02.02.01)] --> Solo para RetieneXFC = 1
IF (SELECT COUNT(*) FROM dbo.xRetencionDet WITH (NoLock) WHERE OpBatNbr = @zBatNbr AND Session = @Session AND RetieneXFC = 1 AND DocType = 'AD') > 0 BEGIN

	IF @iDebug = 1 SELECT  '>> Neteando VO/AC <-> AD ' 

	--| Genero el monto a netear 
	UPDATE x SET 
		S4Future03 = BaseCalculoNeteo
	FROM dbo.xRetencionDet x
	INNER JOIN 
		(
		SELECT C.OpBatNbr, C.Session, C.IdTipoRetencion, C.IdCptoRetencion, SUM(BaseCalculo*PropPago) AS BaseCalculoNeteo
		FROM dbo.xRetencionDet C WITH (NoLock) 
		WHERE C.OpBatNbr = @zBatNbr
		AND   C.Session  = @Session
		AND   C.RetieneXFC = 1
		AND   C.DocType = 'AD'    --> Notas de Crédito
		GROUP BY C.OpBatNbr, C.Session, C.IdTipoRetencion, C.IdCptoRetencion
		) w ON w.OpBatNbr = x.OpBatNbr AND w.Session = x.Session AND w.IdTipoRetencion = x.IdTipoRetencion AND w.IdCptoRetencion = x.IdCptoRetencion
	WHERE x.OpBatNbr = @zBatNbr
	AND   x.Session  = @Session
	AND   x.RetieneXFC = 1
	AND   x.DocType IN ('VO','AC')
	
	--| Genero tabla temporal para Netear
	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpNeteos%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpNeteos') ) 
		DELETE FROM #tmpNeteos
	ELSE 
		CREATE TABLE #tmpNeteos
			(
			Id              INT IDENTITY ,
			DocType         CHAR( 2),
			IdTipoRetencion CHAR(10),
			IdCptoRetencion CHAR(10),
			IdRow           INT     ,
			FCAmt           FLOAT   ,
			NCAmt           FLOAT   ,
			FCNewAmt        FLOAT   ,
			NCNewAmt        FLOAT   , 
			NCNewAmtHist    FLOAT   , 
			OrderExe        INT
			)
	--TRUNCATE TABLE #tmpNeteos
	INSERT INTO #tmpNeteos
		(DocType, IdTipoRetencion, IdCptoRetencion, IdRow, FCAmt, NCAmt, FCNewAmt, NCNewAmt, NCNewAmtHist, OrderExe)
	SELECT 
		d.DocType, d.IdTipoRetencion, d.IdCptoRetencion, d.WrkRecordId, d.BaseCalculoAcum, d.S4Future03 AS NCAmt, 0 AS FCNewAmt, d.S4Future03 AS NCNewAmt, 0 AS NCNewAmtHist, 
		RANK() OVER (PARTITION BY d.IdTipoRetencion ORDER BY d.RefNbr) AS OrderExe
	FROM dbo.xRetencionDet d WITH (NoLock) 
	WHERE d.OpBatNbr = @zBatNbr
	AND   d.Session  = @Session
	AND   d.RetieneXFC = 1
	AND   d.DocType IN ('VO','AC')
	ORDER BY d.IdTipoRetencion, d.IdCptoRetencion, d.RefNbr

	--| Neteo propiamente dicho
	SELECT @iCount01 = MIN(OrderExe), @iHasta01 = MAX(OrderExe) FROM #tmpNeteos
	WHILE @iCount01 <= @iHasta01 BEGIN
		--
		UPDATE #tmpNeteos SET 
			FCNewAmt     = (CASE WHEN FCAmt > NCNewAmt THEN (FCAmt - NCNewAmt) WHEN NCNewAmt = 0 THEN FCAmt ELSE (0) END) ,
			NCNewAmt     = (CASE WHEN FCAmt >= NCNewAmt THEN 0 ELSE (NCNewAmt - FCAmt) END),
			NCNewAmtHist = (CASE WHEN FCAmt >= NCNewAmt THEN 0 ELSE (NCNewAmt - FCAmt) END)
		WHERE OrderExe = @iCount01
		--
		UPDATE x SET 
			NCNewAmt = y.NCNewAmt
		FROM #tmpNeteos x
		INNER JOIN #tmpNeteos y ON y.IdTipoRetencion = x.IdTipoRetencion AND y.IdCptoRetencion = x.IdCptoRetencion --AND y.Id >= x.Id
		WHERE y.OrderExe = @iCount01
		
		IF @iDebug = 1 SELECT '>> Neteando VO/AC <-> AD: ' + CONVERT(VARCHAR(10),@iCount01) AS Tipo, * FROM #tmpNeteos
		--
		SET @iCount01 = @iCount01 + 1
		--
	END

	--| Actualizo tabla de calculo (Solo VO y AC)
	UPDATE x SET
		BaseCalculoAcum = t.FCNewAmt, 
		S4Future04      = t.NCNewAmtHist
	FROM dbo.xRetencionDet x
	INNER JOIN #tmpNeteos t ON t.IdRow = x.WrkRecordId
	WHERE x.OpBatNbr = @zBatNbr
	AND   x.Session  = @Session
	AND   x.RetieneXFC = 1
	AND   x.DocType IN ('VO','AC')

	--| Quito la base de calculo de las notas de credito
	UPDATE x SET
		BaseCalculoAcum = 0
	FROM dbo.xRetencionDet x
	WHERE x.OpBatNbr = @zBatNbr
	AND   x.Session  = @Session
	AND   x.RetieneXFC = 1
	AND   x.DocType IN ('AD')

	IF @iDebug = 1 SELECT  '>> Fin Neteando VO/AC <-> AD ' AS Tipo, * FROM #tmpNeteos
	
	--| Limpio tabla temporal de neteo
	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpNeteos%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpNeteos') ) DELETE FROM #tmpNeteos

END

--| -----------------------------------------------------------------------------------------------------------------------
--|
--| Actualiza bases de calculo para retenciones flotantes (ver: 02.02.17)
--|
IF @iRetManuales = 0 BEGIN

	--| Verifico si hay alguna de las retenciones flotantes en la OP 
	IF (SELECT COUNT(*) 
		FROM dbo.xRetencionDet        x WITH (NoLock)
		INNER JOIN dbo.xTaxBRFlotante f WITH (NoLock) ON f.IdTipoRetencion = x.IdTipoRetencion AND f.IdCptoRetencion = x.IdCptoRetencion
		WHERE x.OpBatNbr = @zBatNbr
		AND   x.Session  = @Session
		) > 0 BEGIN

		--| Actualizo la jurisdiccion del proveedor (la del documento ya la tengo)
		--| Tambien traslado el campo BaseCalculoAcum al BaseCalculoDesc (por que la retencion de base flotante lo va a cambiar)
		UPDATE x SET
			User5           = LTRIM(RTRIM(p.JurisID)),
			BaseCalculoDesc = BaseCalculoAcum
		FROM dbo.xRetencionDet x
		INNER JOIN dbo.xProveedor     p WITH (NoLock) ON p.VendId = x.VendId
		INNER JOIN dbo.xTaxBRFlotante f WITH (NoLock) ON f.IdTipoRetencion = x.IdTipoRetencion AND f.IdCptoRetencion = x.IdCptoRetencion
		WHERE x.OpBatNbr = @zBatNbr
		AND   x.Session  = @Session
	
		--| Calcula la reduccion de la base de calculo (CASOS 1, 2, 4 y 5)
		UPDATE x SET
			BaseCalculoAcum = BaseCalculoDesc * f.BaseRet_Reduc / 100,
			User4           = f.BaseRet_Reduc,
			User3           = 1
		FROM dbo.xRetencionDet x
		INNER JOIN xCptoRetencion     c WITH (NoLock) ON c.IdTipoRetencion = x.IdTipoRetencion and c.IdCptoRetencion = x.IdCptoRetencion 
		INNER JOIN dbo.xTaxBRFlotante f WITH (NoLock) ON f.IdTipoRetencion = x.IdTipoRetencion AND f.IdCptoRetencion = x.IdCptoRetencion
		WHERE x.OpBatNbr = @zBatNbr
		AND   x.Session  = @Session
		AND   f.Activo = 1
		AND   f.FCLocal = CASE WHEN x.JurID = c.JurId THEN 1 ELSE 0 END
		AND   f.Oper_Jur_Prov = CASE WHEN RTRIM(f.JurId_Prov) = RTRIM(x.User5) THEN 'IGUAL' ELSE 'DISTINTO' END
		AND   RTRIM(c.JurId) <> ''
		AND   RTRIM(x.JurID) <> ''
	
		--| Calcula la reduccion de la base de calculo (CASOS 3 y 4)
		UPDATE x SET
			BaseCalculoAcum = BaseCalculoDesc * f.BaseRet_Reduc / 100,
			User4           = f.BaseRet_Reduc,
			User3           = 2
		FROM dbo.xRetencionDet x
		INNER JOIN xCptoRetencion     c WITH (NoLock) ON c.IdTipoRetencion = x.IdTipoRetencion and c.IdCptoRetencion = x.IdCptoRetencion 
		INNER JOIN dbo.xTaxBRFlotante f WITH (NoLock) ON f.IdTipoRetencion = x.IdTipoRetencion AND f.IdCptoRetencion = x.IdCptoRetencion
		WHERE x.OpBatNbr = @zBatNbr
		AND   x.Session  = @Session
		AND   f.Activo = 1
		AND   f.FCLocal = CASE WHEN (x.JurID = c.JurId) THEN 1 ELSE 0 END
		AND   f.Oper_Jur_Prov = 'TODOS'
		AND   RTRIM(c.JurId) <> ''
		AND   ROUND(x.User4,4) = 0
	
	END	

END

--| ------------------------------------------------------------------------------------------------------------
--|     ____        _                      _                            _  _    __     ____        _                        _
--|    |  _ \  ___ | |_  ___  _ __    ___ (_)  ___   _ __    ___  ___  | || |  /  \   / ___| __ _ | |_  ___   __ _   ___   _ __ (_)  __ _
--|    | |_) |/ _ \| __|/ _ \| '_ \  / __|| | / _ \ | '_ \  / _ \/ __| | || |_| () | | |    / _` || __|/ _ \ / _` | / _ \ | '__|| | / _` |
--|    |  _ <|  __/| |_|  __/| | | || (__ | || (_) || | | ||  __/\__ \ |__   _|\__/  | |___| (_| || |_|  __/| (_| || (_) || |   | || (_| |
--|    |_| \_\\___| \__|\___||_| |_| \___||_| \___/ |_| |_| \___||___/    |_|         \____|\__,_| \__|\___| \__, | \___/ |_|   |_| \__,_|
--|                                                                                                          |___/

--|
--| .:Retenciones 4ta Categoría:. 
--| Si tiene impuestos de 4ta categoría entonces ejecuta esta parte
--| > Primero verifica que la OP posea comprobantes a los que les corresponden retenciones de ese tipos
--| > Si existen crea una pequeña tabla temporal a fin de poder calcular que rango le corresponde
--|
SELECT @iHay4taCateg = COUNT(*) 
FROM dbo.xRetencionDet X WITH (NoLock) 
INNER JOIN 
	(
	--|
	--| Tipo que son como de 4ta categoría gorrrrdo
	--|
	SELECT xConceptoRetAlic.IdTipoRetencion, xConceptoRetAlic.IdCptoRetencion, COUNT(*) AS Tot 
	FROM dbo.xConceptoRetAlic WITH (NoLock)
	INNER JOIN dbo.xCptoRetencion WITH (NoLock) ON xCptoRetencion.IdTipoRetencion = xConceptoRetAlic.IdTipoRetencion AND xCptoRetencion.IdCptoRetencion = xConceptoRetAlic.IdCptoRetencion
	WHERE xCptoRetencion.Activo = 1
	GROUP BY xConceptoRetAlic.IdTipoRetencion, xConceptoRetAlic.IdCptoRetencion
	HAVING COUNT(*) > 1
	--|
	) w ON w.IdTipoRetencion = X.IdTipoRetencion AND w.IdCptoRetencion = X.IdCptoRetencion
WHERE X.OpBatNbr = @zBatNbr 
AND X.Session = @Session
--|
IF @iDebug = 1 PRINT  '>> Retenciones de 4ta Categoria: ' + CASE @iHay4taCateg WHEN 0 THEN 'No' ELSE 'Si' END + CHAR(13)
--|
--| Si el flag de 4ta Categoría se prende
--|
IF @iHay4taCateg > 0 BEGIN
	--|
	--| Si es una retención de 4ta Categoría Verifica en que rango corresponde
	--|
	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpAlic4ta%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpAlic4ta') ) 
		DELETE FROM #tmpAlic4ta
	ELSE
		CREATE TABLE #tmpAlic4ta
			(
			Id              INT IDENTITY ,
			IdTipoRetencion CHAR(10),
			IdCptoRetencion CHAR(10),
			IdAlic          INT     ,
			LimiteSup       FLOAT   ,
			LimiteInf       FLOAT
			)
	--TRUNCATE TABLE #tmpAlic4ta
	INSERT INTO #tmpAlic4ta
		(
		IdTipoRetencion, IdCptoRetencion, IdAlic, LimiteSup, LimiteInf
		)
	SELECT C.IdTipoRetencion, C.IdCptoRetencion, C.RecordId, C.LimiteSup, 0 
	FROM dbo.xConceptoRetAlic C WITH (NoLock)
	INNER JOIN 
		(
		--|
		--| Tipo que son como de 4ta categoría gorrrrdo
		--|
		SELECT xConceptoRetAlic.IdTipoRetencion, xConceptoRetAlic.IdCptoRetencion, COUNT(*) AS Tot 
		FROM dbo.xConceptoRetAlic     WITH (NoLock)
		INNER JOIN dbo.xCptoRetencion WITH (NoLock) ON xCptoRetencion.IdTipoRetencion = xConceptoRetAlic.IdTipoRetencion AND xCptoRetencion.IdCptoRetencion = xConceptoRetAlic.IdCptoRetencion
		INNER JOIN 
			(
			SELECT DISTINCT xRetencionDet.IdTipoRetencion, xRetencionDet.IdCptoRetencion
			FROM dbo.xRetencionDet  WITH (NoLock)
			WHERE xRetencionDet.OpBatNbr = @zBatNbr
			) R ON R.IdTipoRetencion = xConceptoRetAlic.IdTipoRetencion AND R.IdCptoRetencion = xCptoRetencion.IdCptoRetencion 
		WHERE xCptoRetencion.Activo = 1
		GROUP BY xConceptoRetAlic.IdTipoRetencion, xConceptoRetAlic.IdCptoRetencion
		HAVING COUNT(*) > 1
		--|
		) Y ON Y.IdTipoRetencion = C.IdTipoRetencion AND Y.IdCptoRetencion = C.IdCptoRetencion
	ORDER BY C.IdTipoRetencion, C.IdCptoRetencion, C.LimiteSup
	--|
	UPDATE X SET
		LimiteInf = Z.LimiteSup 
	FROM #tmpAlic4ta X
	INNER JOIN
		(
		SELECT Id, LimiteSup FROM #tmpAlic4ta
		) Z ON (Z.Id + 1) = X.Id
	--|
	IF @iDebug = 1 SELECT  '>> Impuestos de 4ta Categ: ' AS Tipo, * FROM #tmpAlic4ta 
	IF @iDebug = 1 SELECT  DISTINCT '>> Impuestos de 4ta Categ (DELETE): ' AS Tipo, *, 
		(Q.BaseCalculo + Q.MontoPagado - Q.MinNoImponible) AS CalInf, X.LimiteInf, 
		(Q.BaseCalculo + Q.MontoPagado - Q.MinNoImponible) AS CalSup, X.LimiteSup
		FROM dbo.xRetencionDet Q
		INNER JOIN #tmpAlic4ta X ON X.IdTipoRetencion = Q.IdTipoRetencion AND X.IdCptoRetencion = Q.IdCptoRetencion AND X.LimiteSup = Q.LimiteSup
		WHERE NOT ( (Q.BaseCalculo + Q.MontoPagado - Q.MinNoImponible) > X.LimiteInf AND (Q.BaseCalculo + Q.MontoPagado - Q.MinNoImponible) <= X.LimiteSup ) 
		AND Q.OpBatNbr  = @zBatNbr 
		AND Q.Session   = @Session
	--| 
	--| Marco lineas a eliminar
	UPDATE Q SET 
		User6 = 'Off'
	FROM dbo.xRetencionDet Q
	INNER JOIN #tmpAlic4ta X ON X.IdTipoRetencion = Q.IdTipoRetencion AND X.IdCptoRetencion = Q.IdCptoRetencion AND X.LimiteSup = Q.LimiteSup
	WHERE NOT ( (Q.BaseCalculoAcum + Q.MontoPagado - Q.MinNoImponible) > X.LimiteInf AND (Q.BaseCalculoAcum + Q.MontoPagado - Q.MinNoImponible) <= X.LimiteSup ) 
	AND Q.OpBatNbr  = @zBatNbr
	AND Q.Session   = @Session
	--|
	IF @iDebug = 1 SELECT  '>> Retenciones 4ta Categ Mark DELETE: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId
	--|
	--| Desmarco los Docs que pertenecen a la misma camada de retencion 4ta Categ
	UPDATE Q SET 
		User6 = CASE WHEN v.LimiteSup = Q.LimiteSup AND v.Alicuota = Q.Alicuota THEN '' ELSE 'Off' END
	FROM dbo.xRetencionDet Q
	INNER JOIN 
		(
		SELECT o.IdTipoRetencion, o.IdCptoRetencion, MAX(o.LimiteSup) AS LimiteSup, MAX(o.Alicuota) AS Alicuota
		FROM dbo.xRetencionDet o
		INNER JOIN
			(
			SELECT IdTipoRetencion, IdCptoRetencion
			FROM #tmpAlic4ta
			GROUP BY IdTipoRetencion, IdCptoRetencion
			) p ON p.IdTipoRetencion = o.IdTipoRetencion AND p.IdCptoRetencion = o.IdCptoRetencion 
		WHERE RTRIM(o.User6) = ''
		AND o.OpBatNbr  = @zBatNbr
		AND o.Session   = @Session
		GROUP BY o.IdTipoRetencion, o.IdCptoRetencion
		) v ON v.IdTipoRetencion = Q.IdTipoRetencion AND v.IdCptoRetencion = Q.IdCptoRetencion --AND v.LimiteSup = Q.LimiteSup AND v.Alicuota = Q.Alicuota
	WHERE Q.OpBatNbr  = @zBatNbr
	AND Q.Session   = @Session
	----|
	IF @iDebug = 1 SELECT  '>> Retenciones 4ta Categ DeMark DELETE: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId
	--|
	DELETE Q 
	FROM dbo.xRetencionDet Q
	INNER JOIN
		(
		SELECT IdTipoRetencion, IdCptoRetencion
		FROM #tmpAlic4ta
		GROUP BY IdTipoRetencion, IdCptoRetencion
		) p ON p.IdTipoRetencion = Q.IdTipoRetencion AND p.IdCptoRetencion = Q.IdCptoRetencion 
	WHERE Q.OpBatNbr  = @zBatNbr
	AND Q.Session   = @Session
	AND Q.User6 = 'Off'
	--|
	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpAlic4ta%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpAlic4ta') ) DELETE FROM #tmpAlic4ta
	IF @iDebug = 1 SELECT  '>> Luego del Filtro 4ta Categ: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session
	--|
END

--| -----------------------------------------------------------------------------------------------------------------------
--|
--| Cálculo Retenciones 
--| ...eso... finalmente calcula la retencion...
--|
IF @iDebug = 1 BEGIN  --| Muestra comportamiento del cálculo
	SELECT 'Pseudo Calculo' AS Tipo,
			CASE X.BaseAplic 
				WHEN 'M' THEN
					(
					CASE 
						WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
						 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
						WHEN ((BaseCalculoAcum + MontoPagado) - MinNoImponible) > 0 --AND (ABS(Neto) >= ABS(NetoASuperar)) AND (ABS(Bruto) >= ABS(BrutoASuperar))
						 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
						ELSE 0
					END 
					)
				WHEN 'D' THEN
					(
					CASE 
						WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
						 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
						WHEN ((BaseCalculoAcum + MontoPagado) - MinNoImponible) > 0 AND (ABS(Neto) > ABS(NetoASuperar)) AND (ABS(Bruto) > ABS(BrutoASuperar))
						 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
						ELSE 0
					END 
					)
				WHEN 'L' THEN
					(
					CASE 
						WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
						 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
						WHEN RetieneXFC = 1 AND (((BaseCalculoAcum /** Factor*/)  + MontoPagado) - MinNoImponible) > 0 AND (ABS(Neto) >= ABS(NetoASuperar)) AND (ABS(Bruto) >= ABS(BrutoASuperar))
						 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
						WHEN RetieneXFC = 0 AND (ABS(Neto) > ABS(NetoASuperar)) AND (ABS(Bruto) > ABS(BrutoASuperar))
						 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
						ELSE 0
					END 
					)
				ELSE 0
			END AS Monto,
			(((BaseCalculoAcum /** Factor*/)  + MontoPagado) - MinNoImponible) AS EsMayorACero,
			ABS(Neto) AS Neto, 
			ABS(NetoASuperar) AS NetoASuperar, 
			ABS(Bruto) AS Bruto, 
			ABS(BrutoASuperar) AS BrutoASuperar
	FROM dbo.xRetencionDet X
	INNER JOIN
		(
		SELECT	IdTipoRetencion, IdCptoRetencion, 
				MIN(WrkRecordId) AS Alfa, 
				MAX(WrkRecordId) AS Omega,
				CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END AS Aglutineitor
		FROM dbo.xRetencionDet  WITH (NoLock) 
		WHERE Session      = @Session
		AND OpBatNbr       = @zBatNbr
		GROUP BY IdTipoRetencion, IdCptoRetencion, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END 
		) Z ON Z.IdTipoRetencion = X.IdTipoRetencion AND Z.IdCptoRetencion = X.IdCptoRetencion AND Z.Aglutineitor = (CASE X.RetieneXFC WHEN 1 THEN RTRIM(X.DocType) + RTRIM(X.RefNbr) ELSE '[ALL]' END) AND X.WrkRecordId = Z.Omega
	WHERE Session = @Session
	AND OpBatNbr = @zBatNbr
END
--| Calculo propiamente dicho
UPDATE X SET 
	RetencionCalculada = 
		CASE X.BaseAplic 
			WHEN 'M' THEN --> Retenciones Manuales
				(
				CASE 
					WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
					 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
					WHEN ((BaseCalculoAcum + MontoPagado) - MinNoImponible) > 0 --AND (ABS(Neto) >= ABS(NetoASuperar)) AND (ABS(Bruto) >= ABS(BrutoASuperar))
					 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
					ELSE 0
				END 
				)
			WHEN 'D' THEN --> Retenciones Documento
				(
				CASE 
					WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
					 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
					WHEN ((BaseCalculoAcum + MontoPagado) - MinNoImponible) > 0 AND (ABS(Neto) > ABS(NetoASuperar)) AND (ABS(Bruto) > ABS(BrutoASuperar))
					 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
					ELSE 0
				END 
				)
			WHEN 'L' THEN --> Retenciones Linea
				(
				CASE 
					WHEN LimiteSup > 0 AND ImporteBase > 0 AND ImporteExced > 0 --> 4ta Categoria
					 THEN (ImporteBase + (((BaseCalculoAcum + MontoPagado) - MinNoImponible - ImporteExced) * (Alicuota / 100))) - (MontoRetenido) --* Factor
					WHEN RetieneXFC = 1 AND (((BaseCalculoAcum /** Factor*/)  + MontoPagado) - MinNoImponible) > 0 AND (ABS(Neto) > ABS(NetoASuperar)) AND (ABS(Bruto) > ABS(BrutoASuperar))
					 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
					WHEN RetieneXFC = 0 AND (ABS(Neto) > ABS(NetoASuperar)) AND (ABS(Bruto) > ABS(BrutoASuperar))
					 THEN (((BaseCalculoAcum + MontoPagado) - MinNoImponible) * ((CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END) / 100) - (MontoRetenido)) --* Factor
					ELSE 0
				END 
				)
			ELSE 0
		END
FROM dbo.xRetencionDet X
INNER JOIN
	(
	SELECT	IdTipoRetencion, IdCptoRetencion, 
			MIN(WrkRecordId) AS Alfa, 
			MAX(WrkRecordId) AS Omega,
			CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END AS Aglutineitor
	FROM dbo.xRetencionDet  WITH (NoLock) 
	WHERE Session      = @Session
	AND OpBatNbr       = @zBatNbr
	GROUP BY IdTipoRetencion, IdCptoRetencion, CASE RetieneXFC WHEN 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE '[ALL]' END 
	) Z ON Z.IdTipoRetencion = X.IdTipoRetencion AND Z.IdCptoRetencion = X.IdCptoRetencion AND Z.Aglutineitor = (CASE X.RetieneXFC WHEN 1 THEN RTRIM(X.DocType) + RTRIM(X.RefNbr) ELSE '[ALL]' END) AND X.WrkRecordId = Z.Omega
WHERE Session = @Session
AND OpBatNbr = @zBatNbr


--| -----------------------------------------------------------------------------------------------------------------------
--|
--| Ajustes al Cálculo de las retenciones
--| Ajusta los valores según parámetros de Retención mínima. 
--| 
UPDATE R SET 
	RetencionCalculada2 = R.RetencionCalculada,
	Ok                  = 1
FROM dbo.xRetencionDet R
INNER JOIN
	(
	SELECT CpnyId, CpnyCUIT, BatNbr, RefNbr, DocType, VendId, IdTipoRetencion, IdCptoRetencion, MAX(WrkRecordId) AS Marca
	FROM dbo.xRetencionDet WITH (NoLock) 
	WHERE xRetencionDet.OpBatNbr = @zBatNbr
	AND xRetencionDet.Session = @Session
	GROUP BY CpnyId, CpnyCUIT, BatNbr, RefNbr, DocType, VendId, IdTipoRetencion, IdCptoRetencion, CASE WHEN RetieneXFC = 1 THEN RTRIM(DocType) + RTRIM(RefNbr) ELSE CAST(WrkRecordId AS VARCHAR(10)) END 
	) w ON w.CpnyId = R.CpnyId AND w.CpnyCUIT = R.CpnyCUIT AND w.BatNbr = R.BatNbr AND w.RefNbr = R.RefNbr AND w.DocType = R.DocType AND w.VendId = R.VendId AND w.IdTipoRetencion = R.IdTipoRetencion AND w.IdCptoRetencion = R.IdCptoRetencion AND w.Marca = R.WrkRecordId 
WHERE R.OpBatNbr = @zBatNbr
AND R.Session = @Session
AND ( (R.RetencionCalculada /** R.Factor*/) >= R.RetencionMinima )
--| ||(CODE)(2011-12-23)(mjc)(02.00.18)|| AND ( ABS((R.RetencionCalculada * R.Factor)) >= R.RetencionMinima OR R.RetencionMinima = 0)
AND ( (R.BaseCalculoAcum /** R.Factor*/) >= R.NetoASuperar )
--| ||(CODE)(2011-12-23)(mjc)(02.00.18)|| AND ( ABS((R.BaseCalculoAcum * R.Factor)) >= R.NetoASuperar OR R.NetoASuperar = 0)

--|
IF @iDebug = 1 SELECT  '>> Retenciones Calc: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session  ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId
IF @iDebug = 1 SELECT  '>> TOTAL Ret. Calc : ' AS Tipo, IdTipoRetencion, IdCptoRetencion, JurID, TipoConvId, SUM(RetencionCalculada), SUM(RetencionCalculada2) FROM xRetencionDet WITH (NoLock) WHERE Session = @Session GROUP BY IdTipoRetencion, IdCptoRetencion, JurID, TipoConvId 
IF @iDebug = 1 SELECT  '>> TOTAL Ret. Base : ' AS Tipo, IdTipoRetencion, IdCptoRetencion, BaseAplic, JurID, TipoConvId, SUM(RetencionCalculada), SUM(RetencionCalculada2) FROM xRetencionDet WITH (NoLock) WHERE Session = @Session GROUP BY IdTipoRetencion, IdCptoRetencion, BaseAplic, JurID, TipoConvId 

--| -----------------------------------------------------------------------------------------------------------------------
--|  _      _  _             _                 _  __
--| | |    (_)| |__    ___  _ __  __ _   ___ (_)  ___   _ __   (_)/ /
--| | |    | || '_ \  / _ \| '__|/ _` | / __|| | / _ \ | '_ \    / /
--| | |___ | || |_) ||  __/| |  | (_| || (__ | || (_) || | | |  / /_
--| |_____||_||_.__/  \___||_|   \__,_| \___||_| \___/ |_| |_| /_/(_)
--|
--| Liberación de Retenciones
--| (Funciona con porcentajes negativos tambien. En el caso de algun tipo de castigo impositivo)
--| (ver: 02.02.12) Se agrega una verificacion para que haya una unica liberacion válida
--|
UPDATE xPorLiberRet SET Activa = 0 WHERE VendId = @zVendId AND Activa = 1 AND @zFecharPago > FechaHasta AND DATEDIFF(dd,FechaHasta,GETDATE()) > 30
--|
--| Si hay liberaciones activas para el proveedor de la actual OP
IF (SELECT COUNT(*) FROM xPorLiberRet WITH (NoLock) WHERE VendId = @zVendId AND Activa = 1) > 0 BEGIN

	--| Tabla de trabajo de liberaciones de Retenciones
	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpLiberacion%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpLiberacion') ) 
		DELETE FROM #tmpLiberacion
	ELSE
		CREATE TABLE #tmpLiberacion
			(
			Id              INT IDENTITY ,
			VendId          CHAR(15),
			IdTipoRetencion CHAR(10),
			IdCptoRet       CHAR(10),
			FechaDesde      SMALLDATETIME,
			FechaHasta      SMALLDATETIME,
			LineId          SMALLINT, 
			ToDel           SMALLINT
			)
	--TRUNCATE TABLE #tmpLiberacion
	INSERT INTO #tmpLiberacion
		(
		VendId, IdTipoRetencion, IdCptoRet, FechaDesde, FechaHasta, LineId, ToDel
		)
	SELECT 
		VendId, IdTipoRetencion, IdCptoRet, FechaDesde, FechaHasta, LineId, 1 AS ToDel
	FROM xPorLiberRet WITH (NoLock)
	WHERE VendId = @zVendId
	AND @zFecharPago BETWEEN FechaDesde AND FechaHasta
	AND Activa = 1
	ORDER BY VendId, IdTipoRetencion, IdCptoRet, FechaHasta DESC, LineId DESC
	
	--| Si existen Liberaciones Verifica que no hay mas de una válida por cada retencione
	IF (SELECT COUNT(*) FROM #tmpLiberacion) > 0 BEGIN
		UPDATE x SET 
			ToDel = 0
		FROM #tmpLiberacion x
		INNER JOIN 
			(
			SELECT VendId, IdTipoRetencion, IdCptoRet, MIN(Id) AS Id
			FROM #tmpLiberacion
			GROUP BY VendId, IdTipoRetencion, IdCptoRet
			) w ON w.VendId = x.VendId AND w.IdTipoRetencion = x.IdTipoRetencion AND w.IdCptoRet = x.IdCptoRet AND w.Id = x.Id
			
		--| Elimina de la temporal las Liberaciones cuya FechaHasta sea menor (Asi queda una sola liberacion por retencion)
		DELETE FROM #tmpLiberacion WHERE ToDel = 1
	END

	UPDATE X SET 
		Liberacion = xPorLiberRet.Liberacion, 
		RetencionCalculada2 = X.RetencionCalculada2 - (X.RetencionCalculada2 * (xPorLiberRet.Liberacion / 100)),
		S4Future02 = 'Liberacion % '+ RTRIM(LTRIM(CONVERT(VARCHAR(10),xPorLiberRet.Liberacion)))
	FROM dbo.xRetencionDet X
	INNER JOIN dbo.xPorLiberRet ON xPorLiberRet.VendId = X.VendId AND xPorLiberRet.IdTipoRetencion = X.IdTipoRetencion AND xPorLiberRet.IdCptoRet = X.IdCptoRetencion
	INNER JOIN #tmpLiberacion p ON p.VendId = xPorLiberRet.VendId AND p.IdTipoRetencion = xPorLiberRet.IdTipoRetencion AND p.IdCptoRet = xPorLiberRet.IdCptoRet AND p.LineId = xPorLiberRet.LineId
	WHERE Session = @Session
	AND OpBatNbr = @zBatNbr
	AND RetencionCalculada2 <> 0
	AND @zFecharPago BETWEEN xPorLiberRet.FechaDesde AND xPorLiberRet.FechaHasta
	AND xPorLiberRet.Activa = 1
	AND xPorLiberRet.Liberacion <> 0.00

	IF @iDebug = 1 SELECT  '>> Post % Liberacion: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session  ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId

	IF EXISTS( SELECT * FROM TempDb..SysObjects Tmp WHERE Tmp.Name LIKE '%#tmpLiberacion%' AND Tmp.Id = OBJECT_ID('TempDb..#tmpLiberacion') ) DELETE FROM #tmpLiberacion

END
--|

--| -----------------------------------------------------------------------------------------------------------------------
--|     _     _  _                      _           ____              _    _   __  _                  _
--|    / \   | |(_)  ___  _   _   ___  | |_  __ _  |  _ \  ___   ___ | |_ (_) / _|(_)  ___  __ _   __| |  __ _
--|   / _ \  | || | / __|| | | | / _ \ | __|/ _` | | |_) |/ _ \ / __|| __|| || |_ | | / __|/ _` | / _` | / _` |
--|  / ___ \ | || || (__ | |_| || (_) || |_| (_| | |  _ <|  __/| (__ | |_ | ||  _|| || (__| (_| || (_| || (_| |
--| /_/   \_\|_||_| \___| \__,_| \___/  \__|\__,_| |_| \_\\___| \___| \__||_||_|  |_| \___|\__,_| \__,_| \__,_|
--|
--| Alicuota Rectificada
--| (La alicuota rectificada predomina sobre el resto de las alicuotas posibles)
--| 
UPDATE X SET 
	Liberacion = xPorLiberRet.User4, 
	AlicuotaPadron = xPorLiberRet.User4,
	RetencionCalculada2 = (((X.BaseCalculoAcum + X.MontoPagado) - X.MinNoImponible) * ((xPorLiberRet.User4) / 100) - (MontoRetenido)),
	S4Future02 = 'Rect.Alicuota: ' + RTRIM(LTRIM(CONVERT(VARCHAR(10),(CASE WHEN AlicuotaPadron < 0 THEN Alicuota ELSE AlicuotaPadron END))))  + ' -> ' + RTRIM(LTRIM(CONVERT(VARCHAR(10),xPorLiberRet.User4)))
FROM dbo.xRetencionDet X
INNER JOIN dbo.xPorLiberRet ON xPorLiberRet.VendId = X.VendId AND xPorLiberRet.IdTipoRetencion = X.IdTipoRetencion AND xPorLiberRet.IdCptoRet = X.IdCptoRetencion
WHERE Session = @Session
AND OpBatNbr = @zBatNbr
AND RetencionCalculada2 <> 0
AND @zFecharPago BETWEEN xPorLiberRet.FechaDesde AND xPorLiberRet.FechaHasta
AND xPorLiberRet.Activa <> 0
AND xPorLiberRet.User4 <> 0.00
--|
IF @iDebug = 1 SELECT  '>> Post % Rectificada: ' AS Tipo, * FROM xRetencionDet WITH (NoLock) WHERE Session = @Session  ORDER BY IdTipoRetencion, IdCptoRetencion, WrkRecordId

--| ------------------------------------------------------------------------------------------------------------
--|   ____        _                               ____          _
--|  |  _ \  ___ | |_  ___   _ __  _ __    ___   |  _ \   __ _ | |_  ___   ___
--|  | |_) |/ _ \| __|/ _ \ | '__|| '_ \  / _ \  | | | | / _` || __|/ _ \ / __|
--|  |  _ <|  __/| |_| (_) || |   | | | || (_) | | |_| || (_| || |_| (_) |\__ \
--|  |_| \_\\___| \__|\___/ |_|   |_| |_| \___/  |____/  \__,_| \__|\___/ |___/
--|
--| (PASO 5) 
--|
--| Insert en xPrintDetPago (Resultado de los calculos)
--|
INSERT INTO dbo.XPrintDetPago
	(
	BatNbr,VendId,NroCheque,TipoDetalle,CpnyID,DocType,RefNbr,Moneda,ImpOri,ImpLoc,
	IDCptoRetencion,MontoNetoPagado,RetIVAARetener,NroPago,CheckDetBatNbr,
	CheckDetCpnyId,CheckDetCuryDiscAmt,CheckDetCuryId,CheckDetCuryMultDiv,
	CheckDetCuryPmtAmt,CheckDetCuryRate,CheckDetDiscAmt,CheckDetPmtAmt,
	DocCuryRateType,DocCuryRate,DocAcct,DocSub,BaseRetenible,AlicuotaRet,
	FCOriginal,ImporteenLetras
	)
SELECT 
	R.OpBatNbr, R.VendId, /*NroCheque*/ '', /*TipoDetalle*/ 'R', P.CpnyId, /*DocType*/ R.IdTipoRetencion,
	/*RefNbr*/ MAX(R.RefNbr), P.CuryId, /*ImpOri*/ SUM(RetencionCalculada2), /*ImpLoc*/ SUM(RetencionCalculada2),
	R.IdCptoRetencion, MAX(BaseCalculoAcum), /*RetIVAARetener*/ 0, /*NroPago*/ R.NroOPago, 
	/*CheckDetBatNbr*/ '', /*CheckDetCpnyId*/ P.CpnyId, /*CheckDetCuryDiscAmt*/ 0, /*CheckDetCuryId*/ P.CuryId, 
	/*CheckDetCuryMultDiv*/ 0, /*CheckDetCuryPmtAmt*/ 0, /*CheckDetCuryRate*/ 1, /*CheckDetDiscAmt*/ 0, 
	/*CheckDetPmtAmt*/ 0, /*DocCuryRateType*/ '', /*DocCuryRate*/ 1, 
	/*DocAcct*/ '', /*DocSub*/ '', 
	/*BaseRetenible*/ CASE MAX(R.RetieneXFC) WHEN 1 THEN SUM(R.BaseCalculoAcum) ELSE MAX(R.BaseCalculoAcum) END,
	/*AlicuotaRet*/ MAX(CASE AlicuotaPadron WHEN -1 THEN Alicuota ELSE AlicuotaPadron END), 
	/*FCOriginal*/ MAX(InvcNbr), 
	/*ImporteenLetras*/ '' --@zVersion
FROM dbo.xRetencionDet R WITH (NoLock)
INNER JOIN dbo.xApDocPagoMan P WITH (NoLock) ON P.BatNbr = R.OpBatNbr
WHERE R.Session = @Session
AND R.OpBatNbr = @zBatNbr
AND R.Ok = 1
GROUP BY R.OpBatNbr, R.VendId, P.CpnyId, R.IdTipoRetencion, R.IdCptoRetencion, P.CuryId, R.IdCptoRetencion, R.NroOPago
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: xPrintDetPago.'
	SET @iErrCtrl = 0060
	GOTO OutError
END
--|
IF @iDebug = 1 SELECT  '>> xPrintDetPago : ' AS Tipo, * FROM xPrintDetPago WHERE BatNbr = @zBatNbr

--|
--| Insert en xApValPM 
--|
INSERT INTO dbo.xApValPM
	(
	TipoValorID, BatNbr, CpnyId, NroOPago, Acct, Banco, 
	ValorAmt, IDRetencion, Clasif, Clearing, Crtd_DateTime, 
	Crtd_Prog, Crtd_User, CuryValorAmt, CuryDiscBal, CuryDiscTkn, 
	CuryEffDate, CuryId, CuryMultDiv, CuryRate, CuryRateType, 
	DiscBal, DiscDate, DiscTkn, DocDate, DueDate, LineId, LineNbr, 
	LUpd_DateTime, LUpd_Prog, LUpd_User, NroFactura, PayDate, 
	PmtMethod, Propio, 
	S4Future01, S4Future02, S4Future03, S4Future04, S4Future05, S4Future06, 
	S4Future07, S4Future08, S4Future09, S4Future10, S4Future11, S4Future12, 
	Sub, User1, User2, User3, User4, User5, User6, User7, User8, 
	VendId, NroValor
	)
SELECT 
	/*TipoValorID*/ R.IdTipoRetencion, /*BatNbr*/ R.OpBatNbr, /*CpnyId*/ P.CpnyId, /*NroOPago*/ R.NroOPago, 
	/*Acct*/ C.Acct, /*Banco*/ '', /*ValorAmt*/ ROUND(SUM(RetencionCalculada2),2), /*IDRetencion*/ R.IdCptoRetencion, /*Clasif*/ 'RET', 
	/*Clearing*/ 0, /*Crtd_DateTime*/ GETDATE(), /*Crtd_Prog*/ 'XT586', /*Crtd_User*/ P.LUpd_User, 
	/*CuryValorAmt*/ ROUND(SUM(RetencionCalculada2),2), /*CuryDiscBal*/ 0, /*CuryDiscTkn*/ 0, /*CuryEffDate*/ GETDATE(), 
	/*CuryId*/ P.CuryId, /*CuryMultDiv*/ '', /*CuryRate*/ 1, /*CuryRateType*/ '', /*DiscBal*/ 0, 
	/*DiscDate*/ GETDATE(), /*DiscTkn*/ 0, /*DocDate*/ P.DocDate, /*DueDate*/ P.DocDate, /*LineId*/ 0, /*LineNbr*/ 0, 
	/*LUpd_DateTime*/ GETDATE(), /*LUpd_Prog*/ 'XT586', /*LUpd_User*/ P.LUpd_User, /*NroFactura*/ '', 
	/*PayDate*/ P.DocDate, /*PmtMethod*/ '', /*Propio*/ 1, 
	/*S4Future01*/ '', /*S4Future02*/ @zVersion, 
	/*S4Future03*/ CASE WHEN AlicuotaPadron <= 0 THEN Alicuota ELSE AlicuotaPadron END,  --> Alicuota de Retencion
	/*S4Future04*/ CASE MAX(R.RetieneXFC) WHEN 1 THEN SUM(R.BaseCalculoAcum) ELSE MAX(R.BaseCalculoAcum) END,  --> Base Imponible
	/*S4Future05*/ MAX(R.WrkRecordId), --> Referencia desde xApValPM -->> xRetencionDet
	/*S4Future06*/ 0, 
	/*S4Future07*/ '1900-01-01', /*S4Future08*/ '1900-01-01', /*S4Future09*/ 0, /*S4Future10*/ 0, 
	/*S4Future11*/ '', /*S4Future12*/ '', /*Sub*/ C.Sub, 
	/*User1*/ '', /*User2*/ '', /*User3*/ 0, /*User4*/ 0, 
	/*User5*/ '', /*User6*/ '', /*User7*/ '1900-01-01', /*User8*/ '1900-01-01', 
	/*VendId*/ P.VendId, /*NroValor*/ 0
FROM dbo.xRetencionDet R WITH (NoLock)
INNER JOIN dbo.xCptoRetencion C WITH (NoLock) ON C.IdTipoRetencion = R.IdTipoRetencion AND C.IdCptoRetencion = R.IdCptoRetencion 
INNER JOIN dbo.xApDocPagoMan  P WITH (NoLock) ON P.BatNbr = R.OpBatNbr
WHERE R.Session = @Session
AND R.OpBatNbr = @zBatNbr
AND R.Ok = 1
GROUP BY 
	R.IdTipoRetencion, R.OpBatNbr, P.CpnyId, R.NroOPago, C.Acct, R.IdCptoRetencion, 
	P.LUpd_User, P.CuryId, P.DocDate, C.Sub, P.VendId, R.AlicuotaPadron, R.Alicuota, 
	CASE WHEN R.CertifXFC = 1 THEN RTRIM(R.DocType) + RTRIM(R.RefNbr) ELSE '[ALL]' END --> Certificado X Retencion
HAVING SUM(RetencionCalculada2) <> 0.00
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: xApValPM.'
	SET @iErrCtrl = 0070
	GOTO OutError
END
--|
IF @iDebug = 1 SELECT  '>> xApValPM : ' AS Tipo, * FROM xApValPM WHERE BatNbr = @zBatNbr
--|
--| Renumero el xApValPM
--|
UPDATE x SET
	LineId  = x.RecordID - v.LineId,
	LineNbr = -30640 + (x.RecordID - v.LineId)
FROM dbo.xApValPM x
INNER JOIN (SELECT BatNbr, MIN(RecordId) AS LineId FROM dbo.xApValPM WITH (NoLock) WHERE BatNbr = @zBatNbr GROUP BY BatNbr) v ON v.BatNbr = x.BatNbr
WHERE x.BatNbr = @zBatNbr
--|
IF @@ERROR <> 0 BEGIN
	SET @zErrMsg  = 'Error: Numerando xApValPM.'
	SET @iErrCtrl = 0080
	GOTO OutError
END
--|
IF @iDebug = 1 SELECT  '>> xApValPM : ' AS Tipo, * FROM xApValPM WHERE BatNbr = @zBatNbr


--| ------------------------------------------------------------------------------------------------------------
--|	 _____        _  _
--|	| ____|__  __(_)| |_
--|	|  _|  \ \/ /| || __|
--|	| |___  >  < | || |_
--|	|_____|/_/\_\|_| \__|
--|

-- >>>>>>>>>>>>>>>>>>
OutOk:
SET @zErrMsg = 'PROCESO COMPLETADO'
GOTO ThisIsTheEnd

-- >>>>>>>>>>>>>>>>>>
OutError:
SET @zErrMsg = RTRIM(LTRIM(@zErrMsg)) + ':' + RTRIM(LTRIM(CAST(@iErrCtrl AS VARCHAR(10)))) + ':'
GOTO ThisIsTheEnd

-- >>>>>>>>>>>>>>>>>>
ThisIsTheEnd:
IF LTRIM(RTRIM(@zUserId)) <> 'OPGEN' --> Si el proceso no fue llamado desde el generador de OP, devuelve el mensaje, sino no...
	SELECT @zErrMsg
--|


