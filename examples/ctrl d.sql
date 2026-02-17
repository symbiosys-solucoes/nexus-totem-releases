
-- Verifica se tem itens com estoque negativo.

exec sp_executesql N'SELECT  Produtos.CODPRODUTO, Produtos.NOMEPRODUTO, Produtos.Unid, FilLoc=Filiais.NomeFilial + '' / ''+Loc.NomeLocal,  QtdSolicitada=SUM(ISNULL(ItensMov.Qtd,0)* (1/Itensmov.FatorConvUnid)), SDOATUAL=ISNULL(Estoque.SdoAtual,0)
FROM dbo.Produtos Produtos (NOLOCK), Estoque (NOLOCK),  Movimento Mov (NOLOCK), ItensMov LEFT JOIN LocalEstoque Loc ON ItensMov.IdLocalEstoqueItem = Loc.IdLocalEstoque INNER JOIN Filiais ON Loc.CodFilial = Filiais.CodFilial
WHERE (ItensMov.IdMov         = Mov.IdMov)
  AND (ItensMov.IdProduto     = Estoque.IdProduto)
  AND (Estoque.CodFilial      = Loc.CodFilial) AND (Estoque.CodLocal = Loc.CodLocal)
  AND (ItensMov.IdProduto     = Produtos.IdProduto) AND (Produtos.TipoProduto <> ''S'') AND ISNULL(Loc.AceitaEstoqueNegativo,''N'')=''N'' AND ISNULL(Produtos.AceitaEstoqueNegativoProd,''N'')=''N''


  AND (ItensMov.IdMov         = @P1)


GROUP BY  Produtos.CODPRODUTO, Produtos.NOMEPRODUTO, Produtos.Unid, Loc.CodFilial, Filiais.NomeFilial, Loc.CodLocal, Loc.NomeLocal, ISNULL(Estoque.SdoAtual,0)
HAVING  ISNULL(Estoque.SdoAtual,0)    < SUM(ISNULL(ItensMov.Qtd,0)* (1/Itensmov.FatorConvUnid))

ORDER BY Produtos.NOMEPRODUTO
',N'@P1 int', 4421235 -- idmov

-----------------------------------------------------------


-- Criar os movimentos de venda a partir de um orçamento dividindo em filiais e locais

DECLARE
  @IdMovORC 		INT,
  @CODFILIALORIG 	VARCHAR(2), @CODLOCALORIG VARCHAR(2), @UnidItemMov  VARCHAR(4), @AceitaEstoqueNegativoProd  VARCHAR(1),
  @NUMEROMOV 		VARCHAR(20),  @CodVendedor  VARCHAR(5),   @PrecoUnit MONEY,
  @DtMov			DATETIME, @IdPrecoTabela VARCHAR(1),  @PrioridadeEntregaItem  VARCHAR(1), @StatusSeparacaoOrig VARCHAR(1), @CodVendedorItem  VARCHAR(5),
  @Qtd          	NUMERIC(15,6), @AceitaEstoqueNegativo  VARCHAR(1),  @IdItemGrade  INT, @ObservacaoItem VARCHAR(300),
  @SdoAtual      	NUMERIC(15,6), @PercDescontoItem NUMERIC(15,6),
  @IdItemMovOrig	INT, @IdMovNew INT, @IdMovAssociado INT, @ValorItemFrete MONEY,   @ValorItemOutDespesas MONEY,
  @IdItemMovNew  	INT, @FatorConvUnid NUMERIC(15,6), @QtDecimaisConv INT,
  @IdProduto	 	INT,
  @SeqItemMov       INT




SELECT  @IdMovORC   = 4421235




DECLARE xItens CURSOR SCROLL FOR
 SELECT im.IdItemMov,
        Loc.CodFilial,
        Loc.CodLocal,
        im.IdProduto,
	     	ISNULL(im.PrioridadeEntregaItem,'R')
  FROM  Movimento MOrc, ItensMov im, Produtos P, LocalEstoque Loc
 WHERE (MOrc.IdMov       = @IdMovORC) AND (MOrc.IdMov = im.IdMov)
   AND (im.IdProduto     = P.IdProduto)
   AND (im.IdLocalEstoqueItem = Loc.IdLocalEstoque)


ORDER BY Loc.CodFilial, Loc.CodLocal, im.IdItemMov


OPEN xItens

FETCH FIRST FROM xItens
 INTO @IdItemMovOrig,
      @CodFilialOrig,
      @CodLocalOrig,
      @IdProduto,
	    @PrioridadeEntregaItem


SET @IdMovNew  = NULL
SET @IdItemMovNew = NULL
SET @NumeroMov = ''

WHILE @@FETCH_STATUS = 0
BEGIN


  SELECT @IdMovNew = ISNULL(MAX(m.IdMov),0)
    FROM Movimento m
   WHERE m.TipoMov        = '2.1'
     AND m.CodFilial      = @CodFilialOrig
     AND m.CodLocal       = @CodLocalOrig
     AND ISNULL(m.PrioridadeEntrega,'R')  = @PrioridadeEntregaItem
     AND m.IdMovOrigem    = @IdMovORC


  IF @IdMovNew = 0
  BEGIN

   EXEC @IdMovNew = sp_NextId 'Movimento'
   EXEC sp_NumeroMovimento '2.1', 1, 0, @NumeroMov OUTPUT

   INSERT INTO MOVIMENTO (IDMOV, CODFILIAL, CODLOCAL,   TIPOMOV, NUMMOV, DTMOV, CodCliFor, IdRegiao, CodVendedor, PercComissao,  CodFuncionario2, PercComissao2, CODCONDPAG, DataEntradaSaida, PercDesconto, PrioridadeEntrega, IdMovOrigem, STATUS, Observacoes, DataAutorizacao, IdUsuarioAutorizacao, DataAutorizacaoCom, IdUsuarioAutorizacaoCom, BloqueioComercial, BloqueioFinanceiro, DtFinalizacao, IdUsuarioFinalizacao, StatusSeparacao)
   SELECT @IdMovNew,
          @CodFilialOrig,
          @CodLocalOrig,
	        '2.1',
          @NumeroMov,
          M.DtMov,
		      M.CodCliFor, M.IdRegiao,
          M.CodVendedor, M.PercComissao,  M.CodFuncionario2, M.PercComissao2,
	        M.CODCONDPAG,
	        M.DataEntradaSaida,
		      M.PercDesconto,
		      @PrioridadeEntregaItem,
          @IdMovORC,
          'T',  -- Status: Pendente
          Observacoes,
          M.DataAutorizacao, M.IdUsuarioAutorizacao, M.DataAutorizacaoCom, M.IdUsuarioAutorizacaoCom, M.BloqueioComercial, M.BloqueioFinanceiro, M.DtFinalizacao, M.IdUsuarioFinalizacao, M.StatusSeparacao
	  FROM Movimento M
	 WHERE M.IdMov = @IdMovORC

     -- Já gera novo movimento com status FINALIZADO
     --UPDATE Movimento SET DtFinalizacao= GETDATE(), IdUsuarioFinalizacao = USER, StatusSeparacao = 'F'
     -- WHERE IdMov = @IdMovNew

    SELECT @StatusSeparacaoOrig = MAX(StatusSeparacao) FROM Movimento WHERE IdMov = @IdMovORC
    -- Coloca mov. em digitação para permitir inserção dos itens
    UPDATE Movimento SET StatusSeparacao = 'N' WHERE IdMov = @IdMovNew

		IF NOT EXISTS (SELECT 1 FROM  MovAssociado WHERE IdMovOrigem =  @IdMovORC AND IdMovDestino = @IdMovNew AND TipoAssociacao = '11')
		BEGIN

		 EXEC @IdMovAssociado  = sp_NextId  'MovAssociado'

		 INSERT INTO MovAssociado
		  (IdMovAssociado,  IdMovOrigem,  IdMovDestino, TipoAssociacao)
		  VALUES
		  (@IdMovAssociado, @IdMovORC, @IdMovNew, '11')

		END


  END


  IF 1=1 -- NOT EXISTS (SELECT 1 FROM ItensMov im WHERE im.IdMov = @IdMovNew AND im.IdProduto = @IdProduto)
  BEGIN

     SELECT @SdoAtual   = ISNULL(MAX(e.SdoAtual),0)
       FROM Estoque e
      WHERE e.codfilial = @CodFilialOrig
        AND e.codlocal  = @CodLocalOrig
        AND e.IdProduto = @IdProduto


     SELECT TOP 1
	        @Qtd = im.Qtd,
	        @PrecoUnit = im.PrecoUnit, @IdPrecoTabela = im.IdPrecoTabela,
			@AceitaEstoqueNegativoProd =ISNULL(P.AceitaEstoqueNegativoProd,'N'),
			@PercDescontoItem = im.PercDescontoItem,
		    @CodVendedorItem  = CodVendedorItem,
            @ObservacaoItem   = ObservacaoItem,
            @ValorItemFrete   = ValorItemFrete,
            @ValorItemOutDespesas = ValorItemOutDespesas,
            @UnidItemMov      = UnidItemMov,
	        @FatorConvUnid    = ISNULL(im.FatorConvUnid,1),
            @QtDecimaisConv   = ISNULL(im.QtDecimaisConv,2)
	   FROM ItensMov im, Produtos P
	  WHERE im.IdItemMov = @IdItemMovOrig
	    AND im.IdProduto = P.IdProduto


     SELECT @AceitaEstoqueNegativo = ISNULL(Max(AceitaEstoqueNegativo),'N')
       FROM LocalEstoque
      WHERE Codfilial = @CodFilialOrig
        AND CodLocal  = @CodLocalOrig

      IF @AceitaEstoqueNegativo = 'N' AND @AceitaEstoqueNegativoProd = 'S'
        SET @AceitaEstoqueNegativo = 'S'


       IF (dbo.fn_Fmt2 ( @Qtd * (1 / @FatorConvUnid) , @QtDecimaisConv) > @SdoAtual )  AND (@AceitaEstoqueNegativo='N')
         SELECT @Qtd = @SdoAtual


       IF @Qtd > 0
       EXEC      sp_InsereItemMov  @IdMovNew,
        	     1,
	 	         @IdProduto,
			     @Qtd,
			     @IdPrecoTabela,
			     @PrecoUnit,
		         @PercDescontoItem, --@PercDescontoItem
                 @IdItemGrade,
                 @ObservacaoItem,
                 @UnidItemMov,
                 @IdItemMovNew  OUTPUT,
                 NULL,
                 0.00,  -- PercICMS
                 0.00,  -- PercIPI
                 NULL,  -- PercReducaoBICMS
                 @CodVendedorItem,
                 0,
                 0,
                 NULL,
                 @ValorItemFrete,
                 @ValorItemOutDespesas


   END

   FETCH NEXT FROM xItens
    INTO @IdItemMovOrig,
         @CodFilialOrig,
         @CodLocalOrig,
         @IdProduto,
	     @PrioridadeEntregaItem


END

CLOSE xItens
DEALLOCATE xItens

-- Grava Status do Orçamento original como APROVADO
UPDATE Movimento SET Status = 'Q',  DATAFATURAMENTO = CONVERT(DATETIME,CONVERT(CHAR(10),GETDATE(),102))
 WHERE IdMov = @IdMovORC

-- UPDATE Movimento SET StatusSeparacao=@StatusSeparacaoOrig WHERE IdMov = @IdMovNew


---------------------------------------------------------------------------
-- Valida se o ctrl d foi executado corretamente

exec sp_executesql N'SELECT M2.IDMOV, M2.Status, M2.CodFilial, M2.CodLocal, M2.IdMovimentoGrupo,
  Filial=M2.CodFilial + ''-'' + F.NomeFilial, DtOp=M2.DataOperacao,
  NumGerado=dbo.fn_DscTipoMov(m2.TipoMov) +'' Nº ''+M2.NumMov,
  TotLiquido = dbo.fn_ValorMovimento2( m2.IdMov, m2.TotMov, m2.PercDesconto, m2.ValorSubICMS, m2.ValorFrete, m2.ValorSeguro, m2.OutrasDespesas, m2.ValorIPI, m2.Frete, ''L''),
  DscStatus = dbo.fn_DscStatusMov(m2.Status, m2.TipoMov)
 FROM MovAssociado ma, Movimento M2, Filiais F
WHERE ma.IdMovDestino  = M2.IdMov
 -- AND M2.TipoMov IN (''2.1'',''2.8'',''2.6'',''2.5'')
  AND M2.CodFilial   = F.CodFilial
  AND ma.IdMovOrigem = @P1',N'@P1 int',4421235

---------------------------------------------------------------------------

-- Busca regras de bloqueio a serem executadas que abortam operacao
exec sp_executesql N'SELECT
IdBloqueioMovimento, NomeBloqueio, ExpressaoSQL
FROM BloqueioMovimento
WHERE  TipoBloqueio = @P1 AND TipoAcao = @P2
   AND ISNULL(Inativo,''N'')=''N''
 


ORDER BY ISNULL(OrdemExec,999)
',N'@P1 varchar(8000),@P2 varchar(8000)','COM','FIN'


---------------------------------------------------------------------------

-- Busca regras de bloqueio a serem executadas que fazem bloqueio comercial

SELECT
IdBloqueioMovimento, NomeBloqueio, ExpressaoSQL, TipoAcao
FROM BloqueioMovimento
WHERE TipoAcao = 'AUT' AND TipoBloqueio = 'COM'
   AND ISNULL(Inativo,'N')='N'




ORDER BY ISNULL(OrdemExec,999)

---------------------------------------------------------------------------
 
 -- Finaliza o movimento em caso de sucesso

exec sp_executesql N'UPDATE Movimento SET 
DtFinalizacao= @P1, IdUsuarioFinalizacao = @P2, StatusSeparacao = @P3
 WHERE IdMov = @P4',N'@P1 datetime2,@P2 varchar(8000),@P3 varchar(8000),@P4 int','2025-12-10 14:08:23.3830000','lucascronos','F',4422183

---------------------------------------------------------------------------


