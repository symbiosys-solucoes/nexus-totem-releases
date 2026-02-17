-- Query Busca o financeiro a ser pago

exec sp_executesql N'SELECT CPR.IDEMPRESA, Cpr.PagRec, Cpr.DtEmissao, IDCPR, CPR.CODFILIAL, TipoDoc.Classificacao,  Cpr.CODCLIFOR, Cpr.CODTIPODOC, NUMDOC, DTVENCIMENTO, VALORTITULO, CODCONTA, IDMOV, DTBAIXA, VALORBAIXADO, NUMBOLETO, Portador.NomePortador, Cpr.CODPORTADOR, Cpr.IdUsuario, Cpr.DataOperacao, Cpr.ValorDesconto, Cpr.ValorAcrescimo, Cpr.ValorDevolucao, Cpr.ValorNotaCredito, ValorLiquido = dbo.fn_valorcpr(Cpr.IdCpr,''L'',Cpr.DTVENCIMENTO, NULL), Cpr.Boleto, Cpr.IdRemessa, CPR.ValorIPI, CPR.ValorSubICMS, CPR.ValorExtra, Cpr.ValorCorrecao, MeioPag=dbo.fn_DscMeioPagCPR(Cpr.IdCpr)
FROM CPR Cpr (NOLOCK), Portador (NOLOCK), TipoDoc
WHERE (IDMOV = @P1 OR IDMOV2 = @P2)
  AND (Cpr.CodPortador = Portador.CodPortador)  AND (Cpr.CodTipoDoc = TipoDoc.CodTipoDoc)
ORDER BY IDMOV, DTVENCIMENTO',N'@P1 int,@P2 int',4508333,4508333

-- Query busca creditos

exec sp_executesql N'SELECT Cpr.IdCPR, Cpr.CODFILIAL, Cpr.CODCLIFOR, CPR.CODTIPODOC, NUMDOC, DTEMISSAO, DTVENCIMENTO, VALORTITULO, CODCONTA, DTBAIXA, VALORBAIXADO, NUMBOLETO, Cpr.ValorDesconto, Cpr.ValorAcrescimo, Cpr.Historico, Cpr.IdPlanoConta, V.NomeVendedor, P.NomePortador, TipoDoc.TipoDoc, Cpr.ValorDevolucao, Cpr.IdDevolucao, Cpr.IdNotaCredito, TipoDoc.Classificacao, ValorNotaCredito, ValorCorrecao, ValorIPI, ValorSubICMS,  ValorExtra, Cpr.DataOperacao,
--ValorLiquido = dbo.fn_valorcpr(idcpr,''L'',DTVENCIMENTO,GETDATE()),
ValorMulta   = dbo.fn_valorcpr(idcpr,''M'',DTVENCIMENTO,GETDATE()),
ValorJuros   = dbo.fn_valorcpr(idcpr,''J'',DTVENCIMENTO,GETDATE())
--ValorCorrigido  = dbo.fn_valorcpr(idcpr,''C'',DTVENCIMENTO,GETDATE())
FROM CPR Cpr (NOLOCK) LEFT JOIN Vendedores V (NOLOCK) ON Cpr.CodVendedor = V.CodVendedor, Portador P (NOLOCK), TipoDoc (NOLOCK)
 WHERE (CPR.DTBAIXA IS NULL)  AND (Cpr.DataCancelamento IS NULL) AND (Cpr.IDEMPRESA = P.IDEMPRESA) AND (Cpr.CODPORTADOR = P.CODPORTADOR) AND (Cpr.IDEMPRESA = TipoDoc.IDEMPRESA) AND (Cpr.CODTIPODOC = TipoDoc.CODTIPODOC)
   AND (Cpr.CODCLIFOR = @P1) AND (Cpr.IDEMPRESA = @P2) AND (Cpr.VALORTITULO > 0)
   AND (TipoDoc.Classificacao IN (''C'',''D''))  AND (CPR.IdDevolucao IS NULL)

AND CPR.PagRec = ''P''
 





ORDER BY  DTVENCIMENTO
',N'@P1 varchar(8000),@P2 int','C23437',1


-- Atualiza o Contas a receber roda 1x para cada credito utilizado
exec sp_executesql N'UPDATE CPR
   SET IDDEVOLUCAO   = @P1,
       IDNOTACREDITO = @P2,
       CODCONTA      = @P3,
       DTBAIXA       = @P4,
       ValorBaixado  = @P5
 WHERE IDCPR = @P6',N'@P1 int,@P2 int,@P3 varchar(8000),@P4 datetime2,@P5 decimal(19,4),@P6 int',NULL,2979578,NULL,'2026-01-25 00:00:00',0.7700,2979571


 -- Gerar o novo credito, com o valor restante, caso use creditos que ultrapassem o valor do contas a receber

         DECLARE
             @IdCPR int,  @PercReducaoNew NUMERIC(12,6),   @PercReducaoOrig NUMERIC(12,6),
             @VencChar   char(10), @ValorLiquidoOrig MONEY,
             @Vencimento datetime,
             @ValorDiferenca money


SELECT @IdCpr = 2979571
SELECT @VencChar = '25/01/2026'
SELECT @ValorDiferenca = 999.23

        SELECT @Vencimento = convert(datetime, @VencChar, 103)
        SELECT @ValorLiquidoOrig = dbo.fn_valorcpr(idcpr,'L',DTVENCIMENTO, NULL)
          FROM CPR
         WHERE IDCPR = @IDCPR

        -- Insere novo CPR

        DECLARE @IDCPRNEW INT

        INSERT INTO CPR (IDEMPRESA, PAGREC, CODFILIAL, CODTIPODOC, CODPORTADOR, NUMDOC, CODCLIFOR, DTEMISSAO, DTVENCIMENTO, HISTORICO, VALORTITULO , BOLETO, IDMOV, IDMOVIMENTOGRUPO, TIPOORIGEMCPR, IDMOV2, TIPOORIGEMCPR2, IDPLANOCONTA, CODVENDEDOR, IdExpedicao, PercComissao, CodFuncionario2, PercComissao2, TipoContabil, IDREGIAO, IDCAIXADIARIO, IDBAIXAPARCIALORIG)
            SELECT C.IDEMPRESA,  c.PAGREC, c.CODFILIAL, C.CODTIPODOC, C.CODPORTADOR,
                   CONVERT(VARCHAR(20),C.NUMDOC + 'BP') , C.CODCLIFOR, C.DTEMISSAO, @Vencimento,
                   C.Historico, -- Comentado por Ticiano em 19-04-2016   'Bx parcial do lancto ' + CONVERT(VARCHAR(8), @IDCPR) ,
                   @ValorDiferenca ,'N', C.IDMOV, C.IDMOVIMENTOGRUPO, C.TIPOORIGEMCPR, C.IDMOV2, C.TIPOORIGEMCPR2, C.IDPLANOCONTA, C.CODVENDEDOR, C.IdExpedicao, C.PercComissao, C.CodFuncionario2, C.PercComissao2, C.TipoContabil, C.IDREGIAO, C.IDCAIXADIARIO, @IDCPR
              FROM CPR C
             WHERE C.IDCPR = @IDCPR

         SET @IDCPRNEW = SCOPE_IDENTITY()

        SET @PercReducaoNew = @ValorDiferenca  / @ValorLiquidoOrig

        INSERT INTO CPRRateioCC
        (IdCPR, IdCentroCusto, Valor, Historico)
        SELECT
         @IDCPRNEW, RatOrig.IdCentroCusto, ISNULL(RatOrig.Valor,0) * @PercReducaoNew, RatOrig.Historico
            FROM CPRRateioCC RatOrig
           WHERE RatOrig.IDCPR = @IDCPR

        -- Grava campos no CPR de origem
        UPDATE CPR SET
            IDBAIXAPARCIAL = @IDCPRNEW,
          -- Comentado por Ticiano em 19-04-2016  HISTORICO = 'Lcto Baixado parcialmente. Vr.Original: '+ CONVERT(VARCHAR(15), dbo.fn_valorcpr(idcpr,'L',DTVENCIMENTO,GETDATE()) ),
            ValorLiquidoOrig = dbo.fn_valorcpr(idcpr,'L',DTVENCIMENTO, NULL),
            VALORTITULO = VALORBAIXADO,
            VALORDESCONTO = 0,
            VALORACRESCIMO = 0,
            VALORCORRECAO  = 0,
            VALORDEVOLUCAO = 0,
            VALORNOTACREDITO = 0,
            ValorExtra = 0,
            ValorIPI = 0,
            ValorSubICMS = 0,
            VALORJUROS = 0,
            VALORMULTA = 0
         WHERE IDCPR = @IDCPR

         SET @PercReducaoOrig = 1 - @PercReducaoNew

         UPDATE CPRRateioCC SET Valor = ISNULL(Valor,0) * @PercReducaoOrig
          WHERE IDCPR = @IDCPR


-- vincula a devolução ao financeiro
exec sp_executesql N'UPDATE CPR
   SET ValorDevolucao   = ISNULL((SELECT SUM(dbo.fn_valorcpr(CPRDEV.IdCpr,''L'',CPRDEV.DTVENCIMENTO,NULL)) FROM CPR CPRDEV (NOLOCK) WHERE CPRDEV.IdDevolucao = CPR.IdCpr),0.00),
       ValorNotaCredito = ISNULL((SELECT SUM(dbo.fn_valorcpr(CPRDEV.IdCpr,''L'',CPRDEV.DTVENCIMENTO,NULL)) FROM CPR CPRDEV (NOLOCK) WHERE CPRDEV.IdNotaCredito = CPR.IdCpr),0.00)
 WHERE IdCpr = @P1


UPDATE CPR SET DtBaixa = GETDATE(), ValorBaixado = 0.00
 WHERE IdCpr = @P2
   AND dbo.fn_valorcpr(IdCpr,''L'',DTVENCIMENTO,NULL) <= 0.00
',N'@P1 int,@P2 int',2979578,2979578