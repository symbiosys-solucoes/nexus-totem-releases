  -----

  -- Passo 1 - Gera movimento relacionado
  
  DECLARE
  @CODCLIFOR   		VARCHAR(7), @IDEMPRESA INT,
  @DATAFECHAMENTO  	DATETIME,
  @DATAFECHAMENTOCHAR  	CHAR(10),
  @DATAINICIO  		DATETIME,
  @DATAFIM     		DATETIME,
  @IDMOVIMENTOGRUPO 	INT



SELECT @CodCliFor = 'C23437'
SELECT @DataFechamentoChar = '10/12/2025'
SELECT @IdEmpresa = 1
  SELECT @DATAFECHAMENTO = convert(datetime, @DATAFECHAMENTOCHAR, 103)

  DECLARE            @TIPOMOV VARCHAR(3),
                     @CODFILIAL VARCHAR(2),
 		                 @NumMov    VARCHAR(20),
 		                 @Operacao  VARCHAR(1),
                     @TOTMOV MONEY,
                     @TotalVendas MONEY,
                     @TotalDevolucoes MONEY, @MovRelacSemExpedicao  VARCHAR(1),  @IdExpedicaoMR INT,
		                 @TotalMovimento  MONEY,   @OUTRASDESPESAS  MONEY,  @ValorSubICMS MONEY, @ValorIPI MONEY, @ValorFrete MONEY, @ValorSeguro MONEY,
		                 @PERCDESCONTO NUMERIC(15,6),
                     @DTVENC DATETIME,
                     @IDCPR INT,
                     @IDMOV INT,
                     @CODTIPODOC VARCHAR(2),
                     @STATUS CHAR(1),
		                 @Result INT,
                     @NPARC INT,
		                 @HISTORICO VARCHAR(255)



      DECLARE   xMOV SCROLL CURSOR FOR
                SELECT   Operacao = CASE WHEN M.TIPOMOV IN ('2.1','2.4','2.5','2.6','8.1') THEN 'V' WHEN M.TIPOMOV IN ('2.3','2.8') THEN 'D' END,
                         M.CODFILIAL,
                         M.IDMOV,
			                   M.NUMMOV,
                         M.TOTMOV,
 		                     M.PERCDESCONTO,
                         M.STATUS, M.OUTRASDESPESAS,  m.ValorSubICMS,  m.ValorIPI,  m.ValorFrete,  m.ValorSeguro, M.TIPOMOV
                    FROM MOVIMENTO M
                   WHERE (M.STATUS IN ('A','T'))
		                 AND (M.IdMovimentoGrupo IS NULL )
		                 AND (M.TOTMOV <> 0)
                     AND (M.TIPOMOV IN ('2.1','2.3','2.8','2.4','2.5','2.6','8.1') )
                     AND (M.CODCLIFOR = @CODCLIFOR)
AND ( M.IDMOV IN (4422184,4422183,4422184))

      FOR READ ONLY


      EXEC  @IdMovimentoGrupo =  sp_NextID 'MovimentoGrupo'

      SELECT @Result = 0


      OPEN xMov
      FETCH FIRST FROM xMov
      INTO  @Operacao,
	          @CodFilial,
 	          @IdMov,
            @NumMov,
 	          @TotMov,
	          @PercDesconto,
            @Status,
            @OutrasDespesas, @ValorSubICMS, @ValorIPI, @ValorFrete, @ValorSeguro,
            @TipoMov

      BEGIN TRANSACTION

      INSERT INTO MovimentoGrupo (IdEmpresa, CodFilial, IdMovimentoGrupo, CodCliFor, DataFechamento)
      VALUES (@IdEmpresa,
              @CodFilial,
              @IdMovimentoGrupo,
	            @CodCliFor,
	            @DataFechamento
	           )

      IF @@ERROR <> 0
      BEGIN
         SELECT @Result = -90
         ROLLBACK TRANSACTION
      END

      SELECT @TotalVendas = 0
      SELECT @TotalDevolucoes = 0
      SELECT @Historico = 'Mov.Relacionados: '

      WHILE @@FETCH_STATUS = 0
      BEGIN

            IF EXISTS (SELECT 1 FROM dbo.fn_MovFisc('D',@IDMOV) f WHERE f.STATUSMOV IN ('A RECEBER','PARC.QUITADO','QUITADO')  OR f.IdMovimentoGrupo IS NOT NULL )
            BEGIN
                 RAISERROR ( 'Existe faturamento gerado na Nota Fiscal originada deste Pedido.',18, 255)
                 SELECT @Result = -91
                 CLOSE xMov
                 DEALLOCATE xMov
                 ROLLBACK TRANSACTION
                 RETURN
            END

            IF @Status = 'A'
              EXEC SP_REMOVECPR @IdMov , 'V'

            IF @Operacao IN ('V','O')
               SELECT @TotalVendas = @TotalVendas + dbo.fn_ValorMovimento2( @IdMov, @TotMov, @PercDesconto, @ValorSubICMS, @ValorFrete, @ValorSeguro,  @OutrasDespesas, @ValorIPI, 0, 'L')
            ELSE IF @Operacao = 'D'
            BEGIN
               SELECT @TotalDevolucoes = @TotalDevolucoes + (dbo.MultV(@TipoMov)*dbo.fn_ValorMovimento2( @IdMov, @TotMov, @PercDesconto, @ValorSubICMS, @ValorFrete, @ValorSeguro, @OutrasDespesas, @ValorIPI, 0, 'L'))
  	           UPDATE Movimento SET Status = 'Q'
   	            WHERE CodFilial = @CodFilial
	                AND IdMov     = @IdMov
            END


            SELECT @Historico = @Historico + @Operacao+'-'+@NumMov+'  '

	    UPDATE Movimento SET IdMovimentoGrupo = @IdMovimentoGrupo
	     WHERE CodFilial = @CodFilial
	       AND IdMov     = @IdMov


 	    IF @@ERROR <> 0
            BEGIN
              SELECT @Result = -92
              ROLLBACK TRANSACTION
            END

            FETCH NEXT FROM xMov
             INTO   @Operacao,
		                @CodFilial,
		                @IdMov,
	                  @NumMov,
	 	                @TotMov,
		                @PercDesconto,
                    @Status,
                    @OutrasDespesas, @ValorSubICMS, @ValorIPI, @ValorFrete, @ValorSeguro,
                    @TipoMov

      END

      CLOSE xMov
      DEALLOCATE xMov

      SELECT @TotalMovimento = ISNULL(@TotalVendas,0) + ISNULL(@TotalDevolucoes,0)

      SELECT @MovRelacSemExpedicao=ISNULL(MAX(MovRelacSemExpedicao),'N') FROM Parametros

      IF @MovRelacSemExpedicao = 'S'
         SELECT @IdExpedicaoMR = NULL
      ELSE
         SELECT @IdExpedicaoMR = MAX(mov.IdExpedicao) FROM Movimento mov WHERE mov.IdMovimentoGrupo=@IdMovimentoGrupo

      UPDATE MovimentoGrupo SET TotalMovimento = @TotalMovimento,
                                IdExpedicao    = @IdExpedicaoMR,
                                Historico      = CONVERT(VARCHAR(255),@Historico)
       WHERE IdMovimentoGrupo = @IdMovimentoGrupo

      -- Grava como Quitado todas as vendas se o mov.relac for zerado
      IF (@TotalMovimento >= 0) AND (@TotalMovimento < 0.02)
      BEGIN

        DECLARE xMovto SCROLL CURSOR FOR
         SELECT IdMov
           FROM Movimento
          WHERE IdMovimentoGrupo IS NOT NULL  AND IdMovimentoGrupo = @IdMovimentoGrupo
        FOR READ ONLY
        OPEN xMovto
        FETCH FIRST FROM xMovto
         INTO @IdMov
        WHILE @@FETCH_STATUS = 0
        BEGIN

           UPDATE Movimento SET Status = 'Q',
                                DataFaturamento = CONVERT(DATETIME,CONVERT(CHAR(10),GETDATE(),102)) ,
                                DataQuitacao    = CONVERT(DATETIME,CONVERT(CHAR(10),GETDATE(),102))
           WHERE IdMov = @IdMov

           FETCH NEXT FROM xMovto
            INTO @IdMov
        END
        CLOSE xMovto
        DEALLOCATE xMovto
      END

       IF @@ERROR <> 0
       BEGIN
          SELECT @Result = -91
  	      ROLLBACK TRANSACTION
       END



       IF @@TRANCOUNT	>	0
       BEGIN
          SELECT IdMovimentoGrupoNew=@IdMovimentoGrupo
          COMMIT TRANSACTION
       END



--- 

-- Passo 2 - Consulta se o relacionamento funcionou

exec sp_executesql N'SELECT IdMovimentoGrupo, Movimentogrupo.CodCliFor, DataFechamento, Movimentogrupo.CodCondPag, Historico, Movimentogrupo.TotalMovimento, Movimentogrupo.DataOperacao, Movimentogrupo.IdUsuario, cf.TIPOPESSOA, Cf.CpfCgcCliFor, Cf.NOMECLIFOR
FROM dbo.MovimentoGrupo Movimentogrupo, Cli_For cf, Filiais F
WHERE Movimentogrupo.CodCliFor = @P1 AND Movimentogrupo.IdEmpresa = @P2 AND MovimentoGrupo.CodCliFor = Cf.CodCliFor  AND (MovimentoGrupo.CODFILIAL = F.CODFILIAL)
AND EXISTS (SELECT 1 FROM Movimento m (NOLOCK) WHERE m.IdMovimentoGrupo IS NOT NULL AND m.IdMovimentoGrupo = MovimentoGrupo.IdMovimentoGrupo AND m.Status = ''T'')


ORDER BY Movimentogrupo.DataOperacao DESC',N'@P1 varchar(8000),@P2 int','C23437',1


-----------------------------------

-- Passo 3 atualiza movimento grupo com dados do movimento
exec sp_executesql N'update dbo.MovimentoGrupo
set
  CodFilial = @P1,
  DataFechamento = @P2,
  CodCondPag = @P3
where
  IdMovimentoGrupo = @P4',N'@P1 varchar(2),@P2 datetime2,@P3 varchar(2),@P4 int','08','2026-01-02 00:00:00','16',24109



--------------------------------------

-- Passo 4 - Gera financeiro


   DECLARE
   @IdMovimentoGrupo INT , @IdCaixaDiario INT,
   @NVEZES 	     INT,
   @DIASINTERVALO    INT,
   @DIASPRAZO        INT,
   @CODPORTADOR      VARCHAR(2), @TipoContabil VARCHAR(1), @ValorTituloCPR MONEY, @PercDescFinanc NUMERIC(7,2), @DataDescontoCond DATETIME,  @ValorDescontoCond MONEY,
   @CODCONDPAG       VARCHAR(2), @CODVENDEDOR VARCHAR(5), @PercComissao NUMERIC(6,2), @CodFuncionario2  VARCHAR(5), @PercComissao2 NUMERIC(6,2),
   @DATABASE         DATETIME,
   @DATABASECHAR     CHAR(10)

SELECT @IdMovimentoGrupo = 24109
SELECT @NVEZES = 2
SELECT @DIASINTERVALO = 30
SELECT @DIASPRAZO = 30
SELECT @CODPORTADOR = '11'
SELECT @CODCONDPAG = '16'
SELECT @DATABASECHAR = '02/01/2026'
SELECT @IDCAIXADIARIO = NULL
   SELECT @DATABASE = convert(datetime, @DATABASECHAR, 103)

   DECLARE           @TIPOMOV VARCHAR(3),
		                 @CODCLIFOR   VARCHAR(7),
		                 @HISTORICO   VARCHAR(255),
                     @CODFILIAL VARCHAR(2),  @IdEmpresa INT,
		                 @NumMov    VARCHAR(10),
		                 @Operacao  VARCHAR(1),
                     @TotalMovimento  MONEY,
                     @DTVENC DATETIME,
                     @IDCPR INT,
                     @IDMOV INT,
                     @CODTIPODOC VARCHAR(2), @IDPLANOCONTA INT,
                     @STATUS CHAR(1),
		                 @Result INT,
                     @NPARC INT



    SELECT
           @CODCLIFOR      = MG.CODCLIFOR,
           @CodFilial      = MG.CodFilial,
	         @TOTALMOVIMENTO = MG.TOTALMOVIMENTO,
           @HISTORICO      = MG.HISTORICO,
           @IdEmpresa      = MG.IdEmpresa
      FROM MOVIMENTOGRUPO MG
     WHERE MG.IDMOVIMENTOGRUPO = @IDMOVIMENTOGRUPO

-- Remove CPR se já existir

     EXEC SP_REMOVECPR @IdMovimentoGrupo, 'G'

-- Altera a Condicao de Pagamento

     UPDATE MOVIMENTOGRUPO SET CODCONDPAG = @CODCONDPAG
      WHERE IDMOVIMENTOGRUPO = @IdMovimentoGrupo

     UPDATE MOVIMENTO SET CODCONDPAG = @CODCONDPAG
      WHERE TIPOMOV IN ('2.1','2.4','2.5','2.6','8.1') AND IDMOVIMENTOGRUPO = @IdMovimentoGrupo


     IF @TOTALMOVIMENTO >= 0
     BEGIN
        SELECT TOP 1 @CodVendedor     = M.CODVENDEDOR,
                     @PercComissao    = M.PercComissao,
                     @CodFuncionario2 = M.CodFuncionario2,
                     @PercComissao2   = M.PercComissao2,
                     @TipoMov         = M.TipoMov
          FROM Movimento M WHERE M.IDMOVIMENTOGRUPO = @IdMovimentoGrupo AND M.TipoMov IN ('2.1','2.4','2.5','2.6','8.1')
     END
     ELSE
     BEGIN
        SELECT TOP 1 @CodVendedor     = M.CODVENDEDOR,
                     @PercComissao    = M.PercComissao,
                     @CodFuncionario2 = M.CodFuncionario2,
                     @PercComissao2   = M.PercComissao2,
                     @TipoMov      = M.TipoMov
          FROM Movimento M WHERE M.IDMOVIMENTOGRUPO = @IdMovimentoGrupo AND M.TipoMov IN ('2.3','2.8')
     END

     SELECT TOP 1 @CodTipoDoc = CODTIPODOCFATUR FROM PARAMETROSMOVIMENTO WHERE IdEmpresa = @IdEmpresa AND TipoMov = @TipoMov

     SELECT @PercDescFinanc = MAX(PercDescFinanc) FROM CLI_FOR (NOLOCK) WHERE CODCLIFOR = @CODCLIFOR

     SELECT @IdPlanoConta = IDPLANOCONTA, @TipoContabil = TipoContabilDft
       FROM TIPODOC (NOLOCK)
      WHERE CODTIPODOC = @CODTIPODOC AND IdEmpresa = @IdEmpresa

      SET @Historico = @Historico + '  (Total R$ '+ dbo.fn_FormatFloat(ABS(@TotalMovimento))+')'


      SELECT @NPARC  = 1
      WHILE  ( @NPARC <= @NVEZES)
      BEGIN

            IF @DIASINTERVALO = 30
                 SELECT @DTVENC =  DATEADD(mm, @NPARC - 1, @DATABASE )  + @DIASPRAZO
            ELSE
                 SELECT @DTVENC = ( @DATABASE + ( ( @NPARC-1) * @DIASINTERVALO ))  + @DIASPRAZO

           SET @ValorTituloCPR = CONVERT(NUMERIC(12,2), ABS(@TotalMovimento) / ISNULL(@NVEZES,0))

           IF ISNULL(@PercDescFinanc,0) > 0
           BEGIN
             SET @ValorDescontoCond = CONVERT(NUMERIC(12,2),@ValorTituloCPR * (ISNULL(@PercDescFinanc,0)/100))
             SET @DataDescontoCond = @DTVENC
           END


           INSERT INTO CPR (IDEMPRESA, CODFILIAL, CODTIPODOC, CODPORTADOR, NUMDOC, PAGREC, CODCLIFOR, DTEMISSAO, DTVENCIMENTO, HISTORICO, VALORTITULO, IDMOV, IDMOVIMENTOGRUPO, TIPOORIGEMCPR, IDPLANOCONTA, CODVENDEDOR, PercComissao, CodFuncionario2, PercComissao2, TipoContabil, IDCAIXADIARIO, ValorDescontoCond, DataDescontoCond, NumeroParcela )
                VALUES ( @IDEMPRESA, @CODFILIAL, @CODTIPODOC, @CODPORTADOR,
                         'G'+CONVERT(VARCHAR(5),@IdMovimentoGrupo) + '.' + CONVERT(CHAR(2), @NPARC), (CASE WHEN @TotalMovimento < 0 THEN 'P' ELSE 'R' END), @CODCLIFOR, @DATABASE, @DTVENC, CONVERT(VARCHAR(255),'Parc. '+ CONVERT(CHAR(2), @NPARC)+'/'+CONVERT(CHAR(2), @NVEZES)+' ref ao ' + @Historico), @ValorTituloCPR , NULL, @IdMovimentoGrupo, 'G', @IdPlanoConta, @CodVendedor, @PercComissao, @CodFuncionario2, @PercComissao2, @TipoContabil, @IdCaixaDiario, @ValorDescontoCond, @DataDescontoCond, @NPARC )

           SET @IdCPR = SCOPE_IDENTITY()

           SELECT @NPARC = @NPARC + 1

      END

