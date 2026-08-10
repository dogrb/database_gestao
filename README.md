# Dog do Rubão — Sistema de Gestão

Sistema de gestão do trailer: vendas, cardápio com ficha técnica, estoque, produção com validade, lista de compras e controle financeiro. Com login, papéis de acesso, avisos no celular e dados na nuvem.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O sistema. É isso que abre no endereço principal. |
| `sw.js` | Service worker. Cuida das notificações no celular. |
| `manifest.json` | Deixa o sistema instalável como aplicativo. |
| `icone-192.png` / `icone-512.png` | Ícone do app e das notificações. |
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

## Banco de dados

**Tabelas:** `perfis`, `insumos`, `produtos`, `receitas`, `preparos`, `producoes`, `vendas`, `estoque_lanc`, `reposicao`, `movimentos`, `contas_fixas`, `dividas`, `config`, `push_assinaturas`, `avisos_enviados`, `segredos`

**Relatórios prontos:** `v_custo_produto`, `v_estoque`, `v_vendas_dia`, `v_vendas_mes`, `v_ranking_produtos`, `v_producoes_ativas`

**Segurança:** funções `seg.e_admin()`, `seg.liberado()` e `seg.pode(chave)` fora do schema público, usadas pelas políticas de RLS de todas as tabelas. A tabela `segredos` tem RLS ligado e nenhuma política — só o servidor lê.

**Estoque:** registrado como lista de movimentos (somente acréscimo), nunca como número sobrescrito. O saldo é a soma. Assim dois aparelhos lançando ao mesmo tempo não se atropelam.

**Edge Function `avisar`:** monta e dispara as notificações. Exige token do agendador ou usuário logado.

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

## Como atualizar

1. Edite `index.html` neste repositório
2. Faça o commit descrevendo o que mudou
3. O Cloudflare publica sozinho em menos de um minuto

**Se quebrar:** Cloudflare → projeto → Deployments → versão anterior → *Rollback to this deploy*.
