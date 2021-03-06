public with sharing class EK6_GrupoPoderCloner {

    public class EK6_GrupoPoderClonerException extends Exception {}

    public EK6_GrupoDePoderDAO grupoPoderDAO;
    public EK6_LimiteDAO limiteDAO;
    public EK6_GeradorChaves geradorChaves;
    public EK6_PoderGrupoDePoderDAO poderGrupoDePoderDAO;


    public EK6_GrupoPoderCloner() {
        grupoPoderDAO = new EK6_GrupoDePoderDAO();
        limiteDAO = new EK6_LimiteDAO();
        geradorChaves = new EK6_GeradorChaves();
        poderGrupoDePoderDAO = new EK6_PoderGrupoDePoderDAO();
    }

    public void clonarFilhosDeGrupo(String grupoOrigemId, String grupoDestinoId) {

        List<EK6_GrupoDePoder__c> gruposOrigem = grupoPoderDAO.buscarComRepresentantes(new Set<Id> {grupoOrigemId, grupoDestinoId});

        if (gruposOrigem == null || gruposOrigem.size() != 2) {
            throw new EK6_GrupoPoderClonerException('Não é possível cópia para este grupo. Por favor, selecione outro grupo.'); //alterada a mensagem de erro squad 2020 - Manutencao de poderes
        }

        EK6_GrupoDePoder__c grupoOrigem = (gruposOrigem.get(0).Id == grupoOrigemId ? gruposOrigem.get(0) : gruposOrigem.get(1));
        EK6_GrupoDePoder__c grupoDestino = (gruposOrigem.get(0).Id == grupoDestinoId ? gruposOrigem.get(0) : gruposOrigem.get(1));

        excluirFilhos(grupoDestino);
        salvarGrupoPoderRepresentante(grupoOrigem.GruposDePoderes__r, grupoDestino);
        salvarClonesPoderGrupoPoder(grupoOrigem.PoderesDosGruposDePoderes__r, grupoDestino, grupoOrigem);
    }

    private void excluirFilhos(EK6_GrupoDePoder__c grupoDestino) {
        for (EK6_GrupoPoderRepresentante__c rep : grupoDestino.GruposDePoderes__r) {
            rep.AtivoBln__c = false;
        }
        update grupoDestino.GruposDePoderes__r;

        List<EK6_Representante__c> representantes = pegarTodosRepresentantes(grupoDestino.GruposDePoderes__r);
        delete pegarTodasInformacoes(representantes);
        delete representantes;
        excluirLimites(grupoDestino.PoderesDosGruposDePoderes__r);
        delete grupoDestino.PoderesDosGruposDePoderes__r;
    }

    private void excluirLimites(List<EK6_PoderGrupoPoder__c> poderes) {
        List<EK6_Limite__c> todosLimites = new List<EK6_Limite__c>();
        List<EK6_AssinaturaLimite__c> assinaturas = new List<EK6_AssinaturaLimite__c>();
        List<EK6_LimiteContaCorrente__c> contas = new List<EK6_LimiteContaCorrente__c>();
        List<EK6_ParametrosLimites__c> parametros = new List<EK6_ParametrosLimites__c>();

        Set<String> poderGrupoPoderIds = pegarIds(poderes);

        Map<String, List<EK6_Limite__c>> limitesPorPoder = limiteDAO.buscarLimitesERelacionados(poderGrupoPoderIds);
        for (List<EK6_Limite__c> limites : limitesPorPoder.values()) {
            todosLimites.addAll(limites);
        }

        for (EK6_Limite__c limite : todosLimites) {
            assinaturas.addAll(limite.AssinaturaDosLimites__r);
            contas.addAll(limite.LimitesContasCorrente__r);
            parametros.addAll(limite.ParametrosLimite__r);
        }


        delete assinaturas;
        delete contas;
        delete parametros;
        delete todosLimites;
    }

    private List<EK6_Representante__c> pegarTodosRepresentantes(List<EK6_GrupoPoderRepresentante__c> representantes) {
        List<EK6_Representante__c> reps = new List<EK6_Representante__c>();
        for (EK6_GrupoPoderRepresentante__c representante : representantes) {
            reps.add( new EK6_Representante__c(Id = representante.RepresentanteLkp__c,
                                               InformacaoIndividualLkp__c = representante.RepresentanteLkp__r.InformacaoIndividualLkp__c) );
        }
        return reps;
    }

    private List<EK6_InformacaoIndividual__c> pegarTodasInformacoes(List<EK6_Representante__c> representantes) {
        List<EK6_InformacaoIndividual__c> informacoes = new List<EK6_InformacaoIndividual__c>();
        for (EK6_Representante__c representante : representantes) {
            informacoes.add( new EK6_InformacaoIndividual__c(Id = representante.InformacaoIndividualLkp__c) );
        }
        return informacoes;
    }

    private List<EK6_GrupoPoderRepresentante__c> salvarGrupoPoderRepresentante(List<EK6_GrupoPoderRepresentante__c> representantes, EK6_GrupoDePoder__c grupoDestino) {
        List<EK6_GrupoPoderRepresentante__c> novosPoderRepresentantes = new List<EK6_GrupoPoderRepresentante__c>();

        for (EK6_GrupoPoderRepresentante__c gpr : representantes) {
            novosPoderRepresentantes.add(
                new EK6_GrupoPoderRepresentante__c(
                    AtivoBln__c = true,
                    RepresentanteLkp__c = gpr.RepresentanteLkp__c,
                    GrupoPoderLkp__c = grupoDestino.Id,
                    CargoRepresentanteTxt__c = gpr.CargoRepresentanteTxt__c,
                    ChaveTxt__c = geradorChaves.gerarChaveGrupoPoderRepresentante(grupoDestino.ChaveTxt__c, gpr.RepresentanteLkp__r.ChaveTxt__c)
                )
            );
        }

        upsert novosPoderRepresentantes EK6_GrupoPoderRepresentante__c.ChaveTxt__c;
        return novosPoderRepresentantes;
    }

    private Set<String> pegarIds(List<SObject> objs) {
        Set<String> ids = new Set<String>();
        for (SObject obj : objs) {
            ids.add(obj.Id);
        }
        return ids;
    }

    private List<EK6_PoderGrupoPoder__c> salvarClonesPoderGrupoPoder(List<EK6_PoderGrupoPoder__c> poderes, EK6_GrupoDePoder__c grupoDestino, EK6_GrupoDePoder__c grupoOrigem) {
        List<EK6_PoderGrupoPoder__c> novosPoderes = new List<EK6_PoderGrupoPoder__c>();
        Map<String, EK6_PoderGrupoPoder__c> poderDestinoPorIdPoderOrigem = new Map<String, EK6_PoderGrupoPoder__c>();

        EK6_PoderGrupoPoder__c novoPoder;
        for (EK6_PoderGrupoPoder__c poder : poderes) {
            novoPoder = new EK6_PoderGrupoPoder__c(
                AtivoBln__c = poder.AtivoBln__c,
                PoderLkp__c = poder.PoderLkp__c,
                GrupoPoderMdt__c = grupoDestino.Id,
                ChaveTxt__c = geradorChaves.gerarChavePoderGrupoPoder(grupoDestino.ChaveTxt__c, poder.PoderLkp__r.ChaveTxt__c) );

            novosPoderes.add(novoPoder);
            poderDestinoPorIdPoderOrigem.put(poder.Id, novoPoder);
        }

        insert novosPoderes;

        salvarClonesLimites( pegarIds(poderes), poderDestinoPorIdPoderOrigem, grupoDestino, grupoOrigem);

        return novosPoderes;
    }

    private void salvarClonesLimites(Set<String> poderesGrupoPoderIds, Map<String, EK6_PoderGrupoPoder__c> poderDestinoPorIdPoderOrigem,
                                     EK6_GrupoDePoder__c grupoDestino, EK6_GrupoDePoder__c grupoOrigem) {
        List<EK6_Limite__c> novosLimites = new List<EK6_Limite__c>();
        List<EK6_AssinaturaLimite__c> novasAssinaturas = new List<EK6_AssinaturaLimite__c>();
        List<EK6_LimiteContaCorrente__c> novasContas = new List<EK6_LimiteContaCorrente__c>();
        List<EK6_ParametrosLimites__c> novosParametros = new List<EK6_ParametrosLimites__c>();

        Map<String, List<EK6_Limite__c>> limitesPorPoder = limiteDAO.buscarLimitesERelacionados(poderesGrupoPoderIds);
        List<EK6_Limite__c> limitesOrigem = new List<EK6_Limite__c>();
        for (List<EK6_Limite__c> limites : limitesPorPoder.values()) {
            limitesOrigem.addAll(limites);
        }

        for (EK6_Limite__c limite : limitesOrigem) {
            novosLimites.add(
                new EK6_Limite__c(
                    AtivoBln__c = true,
                    AssinaConjuntoTxt__c = limite.AssinaConjuntoTxt__c,
                    ContaEspecificaTxt__c = limite.ContaEspecificaTxt__c,
                    MoedaTxt__c = limite.MoedaTxt__c,
                    PeriodoTxt__c = limite.PeriodoTxt__c,
                    LimiteDeNmb__c = limite.LimiteDeNmb__c,
                    LimiteAteNmb__c = limite.LimiteAteNmb__c,
                    PoderGrupoPoderLkp__c = poderDestinoPorIdPoderOrigem.get(limite.PoderGrupoPoderLkp__c).Id,
                    ChaveTxt__c = geradorChaves.gerarChaveLimite(poderDestinoPorIdPoderOrigem.get(limite.PoderGrupoPoderLkp__c).ChaveTxt__c)
                )
            );
        }

        insert novosLimites;

        for (Integer i = 0; i < limitesOrigem.size(); i++) {

            novasAssinaturas.addAll( criarClonesAssinaturas(limitesOrigem.get(i).AssinaturaDosLimites__r, novosLimites.get(i), grupoOrigem, limitesOrigem.get(i).ParametrosLimite__r, limitesOrigem.get(i).LimitesContasCorrente__r) ); //alteracoes squad 2020 - Manutencao de poderes
            novasContas.addAll( criarClonesContas(limitesOrigem.get(i).LimitesContasCorrente__r, novosLimites.get(i)) );
            novosParametros.addAll( criarClonesParametros(limitesOrigem.get(i).ParametrosLimite__r, novosLimites.get(i), null) );

        }

        insert novasAssinaturas;
        insert novasContas;
        insert novosParametros;
    }

    //alteracoes squad 2020 - Manutencao de poderes
    private List<EK6_AssinaturaLimite__c> criarClonesAssinaturas(List<EK6_AssinaturaLimite__c> assinaturas, EK6_Limite__c limite, EK6_GrupoDePoder__c grupoOrigem, EK6_ParametrosLimites__c parametroLimiteOrigem, EK6_LimiteContaCorrente__c limiteContaCorrenteOrigem) {

        EK6_Limite__c novoLimite = limiteDAO.findById(limite.Id);
        List<EK6_AssinaturaLimite__c> novasAssinaturas = new List<EK6_AssinaturaLimite__c>();

        Id idGrupoOrigemCopia = grupoOrigem.Id;
        Id idGrupoNovoCopia = novoLimite.PoderGrupoPoderLkp__r.GrupoPoderMdt__r.Id;
        String chaveGrupoNovoCopia = novoLimite.PoderGrupoPoderLkp__r.GrupoPoderMdt__r.ChaveTxt__c;

        Set<Id> idGrupoPoderAssinaturas = new Set <Id>();
        for(EK6_AssinaturaLimite__c assinatura : assinaturas){
            idGrupoPoderAssinaturas.add(assinatura.GrupoPoderLkp__c);
        }

        List<EK6_PoderGrupoPoder__c> poderesGrupoPoderOrigem = poderGrupoDePoderDAO.findByGrupoDePoderIdsAndAtivo(idGrupoPoderAssinaturas);

        for (EK6_AssinaturaLimite__c assinatura : assinaturas) {

            if(assinatura.GrupoPoderLkp__c == grupoOrigem.Id){
            novasAssinaturas.add(
                new EK6_AssinaturaLimite__c(
                    AtivoBln__c = true,
                    QntAssinaturasNmb__c = assinatura.QntAssinaturasNmb__c,
                    GrupoPoderLkp__c = novoLimite.PoderGrupoPoderLkp__r.GrupoPoderMdt__c,
                    LimiteLkp__c = novoLimite.Id,
                    ChaveTxt__c = geradorChaves.gerarChaveAssinaturaLimite(novoLimite.ChaveTxt__c, novoLimite.PoderGrupoPoderLkp__r.GrupoPoderMdt__r.ChaveTxt__c)
                )
            );

            }else{
                novasAssinaturas.add(
                    new EK6_AssinaturaLimite__c(
                        AtivoBln__c = true,
                        QntAssinaturasNmb__c = assinatura.QntAssinaturasNmb__c,
                        GrupoPoderLkp__c = assinatura.GrupoPoderLkp__c,
                        LimiteLkp__c = novoLimite.Id,
                        ChaveTxt__c = geradorChaves.gerarChaveAssinaturaLimite(novoLimite.ChaveTxt__c, assinatura.GrupoPoderLkp__r.ChaveTxt__c)
                    )
                );
                

                novasAssinaturas.addall(criarLimiteComAssinaturaOrigem(novoLimite, assinatura, assinaturas, idGrupoOrigemCopia, idGrupoNovoCopia, chaveGrupoNovoCopia, 
                                                                        poderesGrupoPoderOrigem, parametroLimiteOrigem, limiteContaCorrenteOrigem));
            }
        }
        return novasAssinaturas;
    }
    //fim alteracoes


    //novo metodo squad 2020 - Manutencao de poderes
    private List<EK6_AssinaturaLimite__c> criarLimiteComAssinaturaOrigem(EK6_Limite__c novoLimite, EK6_AssinaturaLimite__c assinatura, List<EK6_AssinaturaLimite__c> 
                        assinaturas, Id idGrupoOrigemCopia, Id idGrupoNovoCopia, String chaveGrupoNovoCopia, List <EK6_PoderGrupoPoder__c> poderesGrupoPoderOrigem, EK6_ParametrosLimites__c parametroLimiteOrigem, EK6_LimiteContaCorrente__c limiteContaCorrenteOrigem){

        EK6_Limite__c novoLimiteOrigem = new EK6_Limite__c();                                                            
        
        for(EK6_PoderGrupoPoder__c poderGrupoPoderOrigem : poderesGrupoPoderOrigem){

            try {                        
            if((poderGrupoPoderOrigem.GrupoPoderMdt__c == assinatura.GrupoPoderLkp__c) 
            && (poderGrupoPoderOrigem.PoderLkp__r.ChaveTxt__c == novoLimite.PoderGrupoPoderLkp__r.PoderLkp__r.ChaveTxt__c)){

            novoLimiteOrigem.AtivoBln__c = true;
            novoLimiteOrigem.AssinaConjuntoTxt__c = novoLimite.AssinaConjuntoTxt__c;
            novoLimiteOrigem.ContaEspecificaTxt__c = novoLimite.ContaEspecificaTxt__c;
            novoLimiteOrigem.MoedaTxt__c = novoLimite.MoedaTxt__c;
            novoLimiteOrigem.PeriodoTxt__c = novoLimite.PeriodoTxt__c;
            novoLimiteOrigem.LimiteDeNmb__c = novoLimite.LimiteDeNmb__c;
            novoLimiteOrigem.LimiteAteNmb__c = novoLimite.LimiteAteNmb__c;
            novoLimiteOrigem.PoderGrupoPoderLkp__c = poderGrupoPoderOrigem.Id;
            novoLimiteOrigem.ChaveTxt__c = geradorChaves.gerarChaveLimite(poderGrupoPoderOrigem.ChaveTxt__c);

            insert novoLimiteOrigem;
            System.debug('Quantidade de Chamadas para inserir novoLimiteOrigem ====> novoLimiteOrigemId '+novoLimiteOrigem.Id);
        }
            } catch (Exception ex) {
                throw new EK6_GrupoPoderClonerException(ex.getMessage());
            }
            
        }
        
        
        EK6_ParametrosLimites__c parametroNovoLimiteOrigem = new EK6_ParametrosLimites__c(
                    AtivoBln__c = true,
                    LimiteLkp__c = novoLimiteOrigem.Id,
                    PossuiAutorizacaoPreviaTxt__c = parametroLimiteOrigem.PossuiAutorizacaoPreviaTxt__c,
                    AutorizacaoPreviaTxt__c = parametroLimiteOrigem.AutorizacaoPreviaTxt__c,
                    PrecisaAutorizacaoPreviaTxt__c = parametroLimiteOrigem.PrecisaAutorizacaoPreviaTxt__c,
                    PossuiObservacaoTxt__c = parametroLimiteOrigem.PossuiObservacaoTxt__c,
                    ObservacaoTxt__c = parametroLimiteOrigem.ObservacaoTxt__c,
                    PossuiVedadoTxt__c = parametroLimiteOrigem.PossuiVedadoTxt__c,
                    VedadoTxt__c = parametroLimiteOrigem.VedadoTxt__c,
                    ChaveTxt__c = novoLimiteOrigem.ChaveTxt__c,
                    //alteracoes squad 2020 - Manutencao de poderes
                    CodigoAutorizacaoTxt__c = parametroLimiteOrigem.CodigoAutorizacaoTxt__c,
                    CodigoObservacaoTxt__c = parametroLimiteOrigem.CodigoObservacaoTxt__c,
                    CodigoVedadoTxt__c = parametroLimiteOrigem.CodigoVedadoTxt__c);
                    //fim alteracoes

        insert parametroNovoLimiteOrigem;
        System.debug('Quantidade de Chamadas para inserir parametroNovoLimiteOrigem ====> parametroNovoLimiteOrigemId '+parametroNovoLimiteOrigem.Id);



        EK6_LimiteContaCorrente__c limiteContaCorrenteOrigemNovo = new EK6_LimiteContaCorrente__c(
            AtivoBln__c = true,
            AgenciaTxt__c = limiteContaCorrenteOrigem.AgenciaTxt__c,
            ContaTxt__c = limiteContaCorrenteOrigem.ContaTxt__c,
            DACTxt__c = limiteContaCorrenteOrigem.DACTxt__c,
            LimiteLkp__c = novoLimiteOrigem.Id);

        limiteContaCorrenteOrigemNovo.ChaveTxt__c = geradorChaves.gerarChaveContaCorrente(novoLimiteOrigem.ChaveTxt__c, limiteContaCorrenteOrigemNovo);
        
        insert limiteContaCorrenteOrigemNovo;
        System.debug('Quantidade de Chamadas para inserir limiteContaCorrenteOrigemNovo ====> limiteContaCorrenteOrigemNovoId '+limiteContaCorrenteOrigemNovo.Id);



        List<EK6_AssinaturaLimite__c> assinaturasNovoLimiteOrigem = new List<EK6_AssinaturaLimite__c>();

        for (EK6_AssinaturaLimite__c assinaturaOrigem : assinaturas) {
                if(assinaturaOrigem.GrupoPoderLkp__c == idGrupoOrigemCopia){
                    assinaturasNovoLimiteOrigem.add(new EK6_AssinaturaLimite__c(
                        AtivoBln__c = true,
                        QntAssinaturasNmb__c = assinaturaOrigem.QntAssinaturasNmb__c,
                        GrupoPoderLkp__c = idGrupoNovoCopia,
                        ChaveTxt__c = geradorChaves.gerarChaveAssinaturaLimite(novoLimiteOrigem.ChaveTxt__c, chaveGrupoNovoCopia),
                        LimiteLkp__c = novoLimiteOrigem.Id
                        ));
                }
                else{
                    assinaturasNovoLimiteOrigem.add(new EK6_AssinaturaLimite__c(
                        AtivoBln__c = true,
                        QntAssinaturasNmb__c = assinaturaOrigem.QntAssinaturasNmb__c,
                        GrupoPoderLkp__c = assinaturaOrigem.GrupoPoderLkp__c,
                        ChaveTxt__c = geradorChaves.gerarChaveAssinaturaLimite(novoLimiteOrigem.ChaveTxt__c, assinaturaOrigem.GrupoPoderLkp__r.ChaveTxt__c),
                        LimiteLkp__c = novoLimiteOrigem.Id
                        ));
                }
        }
         return assinaturasNovoLimiteOrigem;
    }

    private List<EK6_LimiteContaCorrente__c> criarClonesContas(List<EK6_LimiteContaCorrente__c> contas, EK6_Limite__c limite) {
        List<EK6_LimiteContaCorrente__c> novasContas = new List<EK6_LimiteContaCorrente__c>();

        EK6_LimiteContaCorrente__c novaConta;
        for (EK6_LimiteContaCorrente__c conta : contas) {
            novaConta = new EK6_LimiteContaCorrente__c(
                    AtivoBln__c = true,
                    AgenciaTxt__c = conta.AgenciaTxt__c,
                    ContaTxt__c = conta.ContaTxt__c,
                    DACTxt__c = conta.DACTxt__c,
                    LimiteLkp__c = limite.Id
                );
            novaConta.ChaveTxt__c = geradorChaves.gerarChaveContaCorrente(limite.ChaveTxt__c, novaConta);
            novasContas.add(novaConta);
        }

        return novasContas;
    }

    private List<EK6_ParametrosLimites__c> criarClonesParametros(List<EK6_ParametrosLimites__c> parametros, EK6_Limite__c limite, Id novoLimiteOrigemId) {
        List<EK6_ParametrosLimites__c> novosParametros = new List<EK6_ParametrosLimites__c>();
        
        if (novoLimiteOrigemId == null) {            
            for (EK6_ParametrosLimites__c parametro : parametros) {
                novosParametros.add(
                    new EK6_ParametrosLimites__c(
                        AtivoBln__c = true,
                        LimiteLkp__c = limite.Id,
                        PossuiAutorizacaoPreviaTxt__c = parametro.PossuiAutorizacaoPreviaTxt__c,
                        AutorizacaoPreviaTxt__c = parametro.AutorizacaoPreviaTxt__c,
                        PrecisaAutorizacaoPreviaTxt__c = parametro.PrecisaAutorizacaoPreviaTxt__c,
                        PossuiObservacaoTxt__c = parametro.PossuiObservacaoTxt__c,
                        ObservacaoTxt__c = parametro.ObservacaoTxt__c,
                        PossuiVedadoTxt__c = parametro.PossuiVedadoTxt__c,
                        VedadoTxt__c = parametro.VedadoTxt__c,
                        ChaveTxt__c = limite.ChaveTxt__c,
                        //alteracoes squad 2020 - Manutencao de poderes
                        CodigoAutorizacaoTxt__c = parametro.CodigoAutorizacaoTxt__c,
                        CodigoObservacaoTxt__c = parametro.CodigoObservacaoTxt__c,
                        CodigoVedadoTxt__c = parametro.CodigoVedadoTxt__c
                        //fim alteracoes
                    )
                );
            }
        }
        else{

        }

        return novosParametros;
    }
}
