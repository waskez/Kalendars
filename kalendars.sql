use IvantiSM
go
-- Lieldienu datuma iegūšana
DROP FUNCTION IF EXISTS [dbo].[Lieldienas]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Lieldienas] 
( @Year INT ) 
RETURNS SMALLDATETIME 
AS 
BEGIN 
    DECLARE	@EpactCalc INT, @PaschalDaysCalc INT, @NumOfDaysToSunday INT, @EasterMonth INT, @EasterDay INT 

    SET @EpactCalc = (24 + 19 * (@Year % 19)) % 30 
    SET @PaschalDaysCalc = @EpactCalc - (@EpactCalc / 28) 
    SET @NumOfDaysToSunday = @PaschalDaysCalc - ((@Year + @Year / 4 + @PaschalDaysCalc - 13) % 7) 
    SET @EasterMonth = 3 + (@NumOfDaysToSunday + 40) / 44 
    SET @EasterDay = @NumOfDaysToSunday + 28 - (31 * (@EasterMonth / 4)) 
    RETURN 
    ( 
        SELECT CONVERT (SMALLDATETIME, RTRIM(@Year) + RIGHT('0'+RTRIM(@EasterMonth), 2) + RIGHT('0'+RTRIM(@EasterDay), 2)) 
    ) 
END 
GO
-- Vakardiena kā Pirmssvētku diena
DROP PROCEDURE IF EXISTS [dbo].[VakardienaIrPirmssvetkuDiena]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[VakardienaIrPirmssvetkuDiena]
	@Datums smalldatetime
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Skaits INT, @Vakardiena smalldatetime
	SET @Vakardiena = DATEADD(D, -1, @Datums)
	SELECT @Skaits = COUNT(*) FROM dbo.Kalendars WHERE Datums = @Vakardiena  AND (Brivdiena = 0 AND SvetkuDiena = 0)
	IF @Skaits = 1
		UPDATE dbo.Kalendars SET PirmssvetkuDiena = 1 WHERE Datums = @Vakardiena
END
GO
-- Kalendārs
DROP TABLE IF EXISTS [dbo].[Kalendars]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Kalendars](
	[Datums] [smalldatetime] NOT NULL,
	[Brivdiena] [bit] NOT NULL,
	[SvetkuDiena] [bit] NOT NULL,
	[PirmssvetkuDiena] [bit] NOT NULL,
	[Gads] [smallint] NOT NULL,
	[Menesis] [smallint] NOT NULL,
	[Diena] [smallint] NOT NULL,
	[NedelasDiena] [smallint] NOT NULL,
	[Nedela] [smallint] NOT NULL,
 CONSTRAINT [PK_Kalendars] PRIMARY KEY CLUSTERED 
(
	[Datums] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
--Kalendāra aizpildīšana
DECLARE @StartDate DATETIME, @EndDate DATETIME

SET @StartDate = '2017-01-01'
SET @EndDate = '2019-01-01'

DECLARE @Brivdiena bit, @Svetkudiena bit, @Pirmssvetkudiena bit
SET @Brivdiena = 0
SET @Svetkudiena = 0
SET @Pirmssvetkudiena = 0

DECLARE @NedelasDiena int, @CurrentYear int
--Lieldienas var būt no 22. marta līdz 25. aprīlim
DECLARE @LielaPiektdiena smalldatetime, @PirmasLieldienas smalldatetime, @OtrasLieldienas smalldatetime
SET @CurrentYear = DATEPART(YYYY, @StartDate)
SET @PirmasLieldienas = dbo.Lieldienas(@CurrentYear)
SET @LielaPiektdiena = DATEADD(D, -2, @PirmasLieldienas)
SET @OtrasLieldienas = DATEADD(D, 1, @PirmasLieldienas)

SET DATEFIRST 1; --pēc noklusējuma pirmā diena ir 7

WHILE @StartDate <= @EndDate
BEGIN
	SET @Brivdiena = 0
	SET @Svetkudiena = 0
	SET @Pirmssvetkudiena = 0

	-- Lieldienu datumi
	IF(DATEPART(YYYY, @Startdate) <> @CurrentYear)
	BEGIN		
		SET @CurrentYear = DATEPART(YYYY, @StartDate)
		SET @PirmasLieldienas = dbo.Lieldienas(@CurrentYear)
		SET @LielaPiektdiena = DATEADD(D, -2, @PirmasLieldienas)
		SET @OtrasLieldienas = DATEADD(D, 1, @PirmasLieldienas)
	END
	--Brīvdienas sestdiena un svētdiena
	SET @NedelasDiena = DATEPART(dw, @StartDate)
	IF (@NedelasDiena = 6 OR @NedelasDiena = 7) -- DATEFIRST nomainīts uz 1 (noklusētā vērtība ir 7)
		SET @Brivdiena = 1	

	--svētku dienas
	IF(DATEPART(M, @StartDate) = 1 AND DATEPART(D, @StartDate) = 1) -- Jaunas Gads
		SET @Svetkudiena = 1
	ELSE IF(@StartDate = @LielaPiektdiena) -- Lielā Piektdiena
		SET @Svetkudiena = 1
	ELSE IF(@StartDate = @PirmasLieldienas) -- Pirmās Lieldienas
		SET @Svetkudiena = 1
	ELSE IF(@StartDate = @OtrasLieldienas) -- Otrās Lieldienas
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 5 AND DATEPART(D, @StartDate) = 1) -- Darba svētki, Latvijas Republikas Satversmes sapulces sasaukšanas diena
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 5 AND DATEPART(D, @StartDate) = 4) -- Latvijas Republikas Neatkarības deklarācijas pasludināšanas diena
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 6 AND DATEPART(D, @StartDate) = 23) -- Līgo diena
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 6 AND DATEPART(D, @StartDate) = 24) -- Jāni
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 11 AND DATEPART(D, @StartDate) = 18) -- Latvijas Republikas proklamēšanas diena
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 12 AND DATEPART(D, @StartDate) = 24) -- Ziemassvētku vakars
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 12 AND DATEPART(D, @StartDate) = 25) -- Pirmie Ziemassvētki
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 12 AND DATEPART(D, @StartDate) = 26) -- Otrie Ziemassvētki
		SET @Svetkudiena = 1
	ELSE IF(DATEPART(M, @StartDate) = 12 AND DATEPART(D, @StartDate) = 31) -- Vecgada vakars
		SET @Svetkudiena = 1

	IF @Svetkudiena = 1--Ja vakardiena nav Brīvdiena vai SvētkuDiena, tad vakardiena ir PirmssvetkuDiena
		EXEC dbo.VakardienaIrPirmssvetkuDiena @Datums = @StartDate
	
    INSERT INTO Kalendars
    (
        Datums, Brivdiena, SvetkuDiena, PirmssvetkuDiena,
		Gads, Menesis, Diena, NedelasDiena, Nedela
    )
    SELECT @StartDate, @Brivdiena, @Svetkudiena, @Pirmssvetkudiena, 
	DATEPART(YYYY, @Startdate), DATEPART(M, @StartDate), DATEPART(D, @StartDate), DATEPART(DW, @StartDate), DATEPART(WW, @StartDate)

    SET @StartDate = DATEADD(dd, 1, @StartDate)
END

DROP FUNCTION IF EXISTS [dbo].[Lieldienas]
GO
DROP PROCEDURE IF EXISTS [dbo].[VakardienaIrPirmssvetkuDiena]
GO
