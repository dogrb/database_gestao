# Dog do Rubão — Sistema de Gestão

Sistema de gestão do trailer: vendas, cardápio com ficha técnica, estoque, lista de compras e controle financeiro. Com login, papéis de acesso e dados na nuvem.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O sistema. É este que abre no endereço principal. |
| `casa.html` | Painel financeiro pessoal do casal. Separado do negócio de propósito. |
| `banco-de-dados.sql` | Estrutura do banco. Já aplicada — fica como cópia de segurança. |

## Como funciona

Arquivo único, HTML + CSS + JavaScript puro. Sem framework, sem biblioteca externa, sem etapa de build. O navegador abre e roda.

Dados e login no **Supabase**, acessado direto pela API REST (`/auth/v1` e `/rest/v1`), sem a biblioteca `supabase-js`.

Hospedagem no **Cloudflare Pages**, publicação automática a cada commit na branch `main`.

## Acessos

**Administrador** — vê tudo: painel, meta do dia, faturamento, custo, margem, lucro, caixa, dívidas, cardápio, receitas, estoque, compras e equipe.

**Funcionário** — vê apenas **Vender** e **Estoque**. Não tem acesso a nenhum dado financeiro. A restrição está no banco (Row Level Security), não só na tela — o servidor recusa o pedido mesmo fora do aplicativo.

A primeira conta criada vira administrador automaticamente. As seguintes entram bloqueadas até serem liberadas na aba Equipe.

## Banco de dados

**Tabelas:** `perfis`, `insumos`, `produtos`, `receitas`, `vendas`, `estoque_lanc`, `reposicao`, `movimentos`, `contas_fixas`, `dividas`, `config`

**Relatórios prontos:** `v_custo_produto`, `v_estoque`, `v_vendas_dia`, `v_vendas_mes`, `v_ranking_produtos`

**Segurança:** funções `seg.e_admin()` e `seg.liberado()` fora do schema público, usadas pelas políticas de RLS de todas as tabelas.

**Estoque:** registrado como lista de movimentos (append-only), nunca como número sobrescrito. O saldo é a soma. Assim dois aparelhos lançando ao mesmo tempo não se atropelam.

## Regras que o sistema impõe

- Faturamento não é lucro — aparecem em linhas separadas, sempre
- Caixa não é lucro
- Retirada dos sócios não é despesa da empresa
- Nada é estimado: campo sem preenchimento aparece vazio, nunca com um número inventado

## Versões

| Versão | Data | O que mudou |
|---|---|---|
| v1.0 | 10/08/2026 | Primeira versão no ar: login, papéis, vendas, cardápio, ficha técnica, estoque com baixa automática, lista de compras, financeiro, equipe |

## Como atualizar

1. Edite `index.html` neste repositório
2. Faça o commit descrevendo o que mudou
3. O Cloudflare publica sozinho em menos de um minuto

Se quebrar: Cloudflare → projeto → **Deployments** → versão anterior → **Rollback to this deployment**.
