-- Passo 1 - consulta os parametros
exec [DBCRONOS].[sys].sp_sproc_columns_100 N'GeraLan',N'dbo',N'DBCRONOS',NULL,@ODBCVer=3,@fUsePattern=1

--------------------------------

-- passo 2 - gera o titulo
declare @p11 int
set @p11=2
exec [DBCRONOS].[dbo].[GeraLan] 1540618,1,'11',2,30,30,'2020-12-22 00:00:00',NULL,NULL,NULL,@p11 output,NULL,NULL
select @p11


--------------------------------------

-- passo 3 - consulta os titulos
SELECT Cpr.IdCPR, Cpr.CodFilial, Cpr.CODCLIFOR, CODTIPODOC, NUMDOC, DTVENCIMENTO, VALORTITULO, VALORDESCONTO, VALORACRESCIMO, CODCONTA, DTBAIXA, VALORBAIXADO, NUMBOLETO, CODPORTADOR, IdMovimentoGrupo, IdMov, IdRemessa,  ValorLiquido = dbo.fn_valorcpr(idcpr,'L',DTVENCIMENTO,GETDATE())
FROM CPR Cpr
WHERE  (Cpr.IDCPR IS NOT NULL )
AND  (Cpr.IdMovimentoGrupo IS NULL )
AND  (Cpr.IdMov = 1540618)
      




ORDER BY  DTVENCIMENTO
