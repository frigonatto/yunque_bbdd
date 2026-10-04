--USE [yunque_desa]
--GO

--exec sp_changedbowner 'sa'

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO

--Datos Comunes
CREATE SCHEMA DatosComunes
GO

/****** Object:  Table [DatosComunes].[Provincias]    Script Date: 04/10/2026 11:22:48 ******/
CREATE TABLE [DatosComunes].[Provincias](
	[Id] [varchar](1) NOT NULL,
	[Nombre] [varchar](20) NOT NULL,
	[NombreM] [varchar](20) NOT NULL,
 CONSTRAINT [PK_Provincias] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [DatosComunes].[CodigosPostales]    Script Date: 4/10/2026 11:22:22 ******/
CREATE TABLE [DatosComunes].[CodigosPostales](
	[Id] [int] NOT NULL,
	[CodigoPostal] [smallint] NOT NULL,
	[Localidad] [varchar](40) NOT NULL,
	[ProvinciaId] [varchar](1) NOT NULL,
 CONSTRAINT [PK_CodigosPostales] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Index [IDX_CodigoPostales_CodigoPostal]    Script Date: 4/10/2026 11:23:34 ******/
CREATE NONCLUSTERED INDEX [IDX_CodigoPostales_CodigoPostal] ON [DatosComunes].[CodigosPostales]
(
	[CodigoPostal] ASC,
	[Localidad] ASC
)
INCLUDE([Id],[ProvinciaId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Table [DatosComunes].[CodigosPostalesObservaciones]    Script Date: 4/10/2026 11:26:50 ******/
CREATE TABLE [DatosComunes].[CodigosPostalesObservaciones](
	[CodigoPostalId] [int] NOT NULL,
	[Observaciones] [varchar](50) NOT NULL,
 CONSTRAINT [PK_CodigosPostalesObservaciones] PRIMARY KEY CLUSTERED 
(
	[CodigoPostalId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [DatosComunes].[Domicilios]    Script Date: 4/10/2026 11:27:33 ******/
CREATE TABLE [DatosComunes].[Domicilios](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Calle] [varchar](60) NOT NULL,
	[Altura] [varchar](6) NOT NULL,
	[Piso] [varchar](6) NOT NULL,
	[IdCodigoPostal] [int] NOT NULL,
	[AuditoriaDeAlta] [int] NOT NULL,
	[AuditoriaDeUltimaModificacion] [int] NULL,
 CONSTRAINT [PK_Domicilios] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [DatosComunes].[TiposDeDocumentos]    Script Date: 4/10/2026 11:43:57 ******/
CREATE TABLE [DatosComunes].[TiposDeDocumentos](
	[Codigo] [smallint] NOT NULL,
	[Descripcion] [varchar](50) NOT NULL,
 CONSTRAINT [PK_TiposDeDocumentos] PRIMARY KEY CLUSTERED 
(
	[Codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Index [IDX_TiposDeDocumentos_Descripcion]    Script Date: 4/10/2026 11:43:57 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IDX_TiposDeDocumentos_Descripcion] ON [DatosComunes].[TiposDeDocumentos]
(
	[Descripcion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO



--Proveedores

CREATE SCHEMA Proveedores

/****** Object:  Table [Proveedores].[Proveedores]    Script Date: 04/10/2026 11:22:48 ******/
CREATE TABLE [Proveedores].[Proveedores](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Codigo] [varchar](10) NOT NULL,
	[RazonSocial] [varchar](40) NOT NULL,
	[IdDomicilio] [int] NOT NULL,
	[IdTipoDeDocumento] [smallint] NOT NULL,
	[NroDocumento] [varchar](10) NOT NULL
 CONSTRAINT [PK_Proveedores] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO



--CONSTRAINTS

/****** Object:  ForeignKey [FK_CodigosPostales_Provincias]  Script Date: 4/10/2026 12:05:26 ******/
ALTER TABLE [DatosComunes].[CodigosPostales]  WITH CHECK ADD  CONSTRAINT [FK_CodigosPostales_Provincias] FOREIGN KEY([ProvinciaId])
REFERENCES [DatosComunes].[Provincias] ([Id])
ON UPDATE CASCADE
GO
ALTER TABLE [DatosComunes].[CodigosPostales] CHECK CONSTRAINT [FK_CodigosPostales_Provincias]
GO
/****** Object:  ForeignKey [FK_CodigosPostalesObservaciones_CodigosPostales]  Script Date: 4/10/2026 12:06:26 ******/
ALTER TABLE [DatosComunes].[CodigosPostalesObservaciones]  WITH CHECK ADD  CONSTRAINT [FK_CodigosPostalesObservaciones_CodigosPostales] FOREIGN KEY([CodigoPostalId])
REFERENCES [DatosComunes].[CodigosPostales] ([Id])
ON UPDATE CASCADE
GO
ALTER TABLE [DatosComunes].[CodigosPostalesObservaciones] CHECK CONSTRAINT [FK_CodigosPostalesObservaciones_CodigosPostales]
GO
/****** Object:  ForeignKey [FK_Proveedores_Domicilios]  Script Date: 4/10/2026 11:49:06  ******/
ALTER TABLE [Proveedores].[Proveedores]  WITH CHECK ADD  CONSTRAINT FK_Proveedores_Domicilios FOREIGN KEY([IdDomicilio])
REFERENCES [DatosComunes].[Domicilios] ([Id])
GO
ALTER TABLE [Proveedores].[Proveedores] CHECK CONSTRAINT FK_Proveedores_Domicilios
GO
/****** Object:  ForeignKey [FK_Proveedores_TiposDeDocumentos]  Script Date: 10/8/2024 22:12:06  ******/
ALTER TABLE [Proveedores].[Proveedores]  WITH CHECK ADD  CONSTRAINT FK_Proveedores_TiposDeDocumentos FOREIGN KEY([IdTipoDeDocumento])
REFERENCES [DatosComunes].[TiposDeDocumentos] ([Codigo])
GO
ALTER TABLE [Proveedores].[Proveedores] CHECK CONSTRAINT FK_Proveedores_TiposDeDocumentos 
GO
