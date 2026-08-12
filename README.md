# Dog do Rubão — Sistema de Gestão

Sistema de gestão do trailer: vendas, cardápio com ficha técnica, estoque, produção com validade, lista de compras e controle financeiro. Com login, papéis de acesso, avisos no celular e dados na nuvem.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O sistema. É isso que abre no endereço principal. |
| `sw.js` | Service worker. Cuida das notificações no celular. |
| `manifest.json` | Deixa o sistema instalável como aplicativo. |
| `icone-192.png` / `icone-512.png` | Ícone do app e das notificações. |
| `pedir.html` | Checkout público. É onde o cliente monta o pedido. |
| `casal.html` | Painel financeiro pessoal do casal. Separado do negócio de propósito. |
| `banco-de-dados.sql` | Estrutura do banco. Já aplicado — fica como cópia de segurança. |

## Como funciona

Arquivo único, HTML + CSS + JavaScript puro. Sem framework, sem biblioteca externa, sem etapa de build. O navegador abre e roda.

Dados e login no **Supabase**, acessados diretamente pela API REST (`/auth/v1` e `/rest/v1`), sem a biblioteca supabase-js.

Hospedagem no **Cloudflare Pages**, publicação automática a cada commit na branch `main`.

## Acessos

**Administrador** — vê tudo: painel, meta do dia, faturamento, custo, margem, lucro, caixa, dívidas, cardápio, receitas, estoque, produção, compras e equipe.

**Funcionário** — vê apenas o que o administrador liberar, item por item. A restrição está no banco (Row Level Security), não só na tela — o servidor recusa o pedido mesmo fora do aplicativo.

A primeira conta criada vira **administrador principal**. Ela não pode ser excluída nem rebaixada por ninguém, nem por outro administrador. As contas seguintes entram bloqueadas até serem liberadas na aba Equipe.

Ao excluir uma conta, a pessoa perde o acesso na hora, mas tudo o que ela lançou continua no sistema com o nome dela registrado no histórico.

## Compra x preparo

O sistema separa duas coisas que costumam ser confundidas:

- **Insumo de compra** — o que chega do mercado ou do fornecedor. É o que entra na lista de compras.
- **Insumo de preparo** — o que é feito na cozinha a partir dos itens de compra: molhos, purê, cheddar, linguiça pronta. Tem prazo de validade e é acompanhado na aba **Produção**.

Cada lote preparado registra quanto foi feito (g, ml, kg ou unidades), a hora e a validade calculada a partir do preparo. O sistema avisa quando está perto de vencer e quando precisa descartar.

## Avisos no celular

Notificação push nativa do navegador — gratuita, sem serviço contratado. Chega na tela mesmo com o sistema fechado.

- Ligar em **Ajustes → Avisos no celular**. Vale por aparelho.
- No iPhone, é preciso primeiro adicionar o sistema à Tela de Início (o iOS só permite push em app instalado).
- O agendador no Supabase (`pg_cron`) verifica a cada 30 minutos e envia o resumo do dia às 7h.

O que gera aviso: preparo vencido, preparo vencendo nas próximas horas, preparo que não tem lote pronto, insumo abaixo do mínimo, pedido de reposição da equipe, cadastro novo aguardando autorização e conta com poder de administrador.

## Pedidos e checkout

O cliente abre `/pedir.html`, monta o pedido e escolhe retirada ou entrega. O pedido cai direto na aba **Pedidos**, com aviso no celular da equipe e som no aparelho que estiver com a fila aberta.

**Formas de pagamento**, cada uma ligada ou desligada em Ajustes:

- **Na entrega ou retirada** — cartão na maquininha, Pix na hora ou dinheiro com troco. Mantém as taxas que o negócio já tem.
- **Pix antecipado** — mostra o código copia e cola gerado na hora, com valor certo. O pedido só vai para a cozinha depois que alguém confirmar o recebimento.
- **Online** — cartão aprovado antes do preparo, via Mercado Pago. Precisa da credencial cadastrada em Ajustes.

A credencial do provedor fica na tabela `segredos`, que tem RLS ligado e nenhuma política: nem administrador lê pelo aplicativo, só o servidor.

O preço nunca vem do navegador. A função `criar-pedido` busca o valor de cada item no banco e recalcula o total antes de gravar.

**Fila:** novo → preparando → pronto → saiu (só entrega) → entregue. Cada pedido imprime uma notinha de 80mm pela impressora do aparelho.

## Entregas

O entregador entra com a permissão **Trabalhar como entregador** e enxerga só a aba Entregas: as entregas livres e as dele. Nada de financeiro, custo ou cardápio.

Fluxo: pedido fica pronto → entregador toca em **Pegar** (grava quem e a hora da saída) → **Cliente recebeu** (grava a hora da entrega, quanto recebeu e em qual forma). A venda entra no sistema automaticamente, com hora e canal `entrega`.

O administrador acompanha quem está na rua e há quantos minutos, e fecha o **acerto de caixa** — o dinheiro que cada entregador recebeu na mão e ainda não prestou contas, separado por dinheiro, cartão e Pix.

## Compras e fornecedores

Cada compra registra onde foi feita, o preço de cada pacote e quanto rende. Ao salvar, três coisas acontecem sozinhas: o estoque entra, o custo do insumo se atualiza e a saída vai para o financeiro.

Com isso o sistema monta o **comparador**: para cada insumo, o último preço de cada fornecedor já dividido pelo rendimento, com o mais barato destacado e a economia por unidade. Mais o total gasto em cada estabelecimento e a fatia de cada um.

## Rastreio

Toda inserção, alteração e exclusão nas tabelas do negócio fica gravada em `auditoria`, com quem fez, quando, e o antes e depois de cada campo. A aba só aparece para a conta principal — nem outro administrador enxerga.

## Mural de avisos

O sino no cabeçalho guarda o histórico de tudo que o sistema avisou, com contador de não lidos. Tocar em um aviso leva direto para a aba onde o problema está.

## Banco de dados

**Tabelas:** `perfis`, `insumos`, `produtos`, `receitas`, `preparos`, `producoes`, `pedidos`, `pedido_itens`, `acertos`, `fornecedores`, `compras`, `compra_itens`, `vendas`, `estoque_lanc`, `reposicao`, `movimentos`, `contas_fixas`, `dividas`, `config`, `push_assinaturas`, `avisos_enviados`, `mural`, `mural_lido`, `auditoria`, `segredos`

**Relatórios prontos:** `v_custo_produto`, `v_estoque`, `v_vendas_dia`, `v_vendas_mes`, `v_ranking_produtos`, `v_producoes_ativas`, `v_acerto_aberto`, `v_comparador`, `v_preco_fornecedor`, `v_gasto_fornecedor`

**Vendas:** cada venda grava `momento` (data e hora exatas), `canal` (balcão, site, entrega, telefone), quem lançou e o preço praticado. A coluna `data` continua existindo para os relatórios por dia. Pedido marcado como entregue vira venda sozinho.

**Segurança:** funções `seg.e_admin()`, `seg.liberado()` e `seg.pode(chave)` fora do schema público, usadas pelas políticas de RLS de todas as tabelas. A tabela `segredos` tem RLS ligado e nenhuma política — só o servidor lê.

**Estoque:** registrado como lista de movimentos (somente acréscimo), nunca como número sobrescrito. O saldo é a soma. Assim dois aparelhos lançando ao mesmo tempo não se atropelam.

**Edge Functions:** `avisar` monta e dispara as notificações; `criar-pedido` recebe o pedido do checkout e valida os preços no servidor; `pagamento-webhook` confirma o pagamento na fonte antes de liberar a cozinha. Nenhuma delas aceita chamada sem credencial.

**Visitante:** o site público enxerga apenas `cardapio_publico` e a configuração da loja. Não alcança pedidos, clientes, custos nem nada da equipe.

## Regras que o sistema respeita

- Faturamento não é lucro — aparecem em linhas separadas, sempre
- Caixa não é lucro
- Retirada de sócios não é despesa da empresa
- Nada é estimado: campo sem preenchimento aparece vazio, nunca com um número inventado

## Versões

| Versão | Data | O que mudou |
|---|---|---|
| v1.0 | 10/08/2026 | Primeira versão no ar: login, papéis, vendas, cardápio, ficha técnica, estoque com baixa automática, lista de compras, financeiro, equipe |
| v1.1 | 10/08/2026 | Aba Produção com controle de validade; separação entre insumo de compra e de preparo; exclusão de usuário com administrador principal protegido; notificações push no celular; cardápio e fichas técnicas carregados do catálogo |
| v1.3 | 12/08/2026 | Entregador com registro de saída e chegada, acerto de caixa e venda automática na entrega; filtro de período no painel com faixa de horário; venda registrada uma a uma com hora; fornecedores, compras e comparador de preços; trilha de auditoria restrita à conta principal |
| v1.2 | 10/08/2026 | Mural de avisos no sino do cabeçalho; aba Pedidos com fila de cozinha, pedido no balcão e notinha de 80mm; checkout público em `/pedir.html` com retirada ou entrega e três formas de pagamento |

## Como atualizar

1. Edite `index.html` neste repositório
2. Faça o commit descrevendo o que mudou
3. O Cloudflare publica sozinho em menos de um minuto

**Se quebrar:** Cloudflare → projeto → Deployments → versão anterior → *Rollback to this deploy*.
