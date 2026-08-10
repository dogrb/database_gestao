-- =====================================================================
-- DOG DO RUBAO - BANCO DE DADOS COMPLETO
-- JA FOI APLICADO no projeto dogdorubao em 10/08/2026.
-- Este arquivo fica como copia de seguranca e referencia.
-- Pode rodar de novo sem medo: nao apaga nada que ja existe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PERFIS E PERMISSOES
-- ---------------------------------------------------------------------
create table if not exists perfis (
  id        uuid primary key references auth.users(id) on delete cascade,
  nome      text,
  email     text,
  telefone  text,
  papel     text not null default 'funcionario' check (papel in ('admin','funcionario')),
  aprovado  boolean not null default false,
  criado_em timestamptz not null default now()
);

-- O PRIMEIRO que se cadastrar vira ADMIN e ja entra liberado.
-- Todos os seguintes entram como funcionario e ficam bloqueados ate voce aprovar.
create schema if not exists seg;
revoke all on schema seg from anon, authenticated;
grant usage on schema seg to authenticated;

create or replace function seg.criar_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare primeiro boolean;
begin
  select count(*) = 0 into primeiro from perfis;
  insert into perfis (id, nome, email, telefone, papel, aprovado)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    new.email,
    new.raw_user_meta_data->>'telefone',
    case when primeiro then 'admin' else 'funcionario' end,
    primeiro
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function seg.criar_perfil();

create or replace function seg.e_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and papel = 'admin' and aprovado);
$$;

create or replace function seg.liberado() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and aprovado);
$$;

-- As funcoes ficam fora do schema publico para nao serem chamaveis pela API.
revoke all on function seg.e_admin()      from public, anon;
revoke all on function seg.liberado()     from public, anon;
revoke all on function seg.criar_perfil() from public, anon, authenticated;
grant execute on function seg.e_admin()  to authenticated;
grant execute on function seg.liberado() to authenticated;

-- ---------------------------------------------------------------------
-- 2. TABELAS DO NEGOCIO
-- ---------------------------------------------------------------------
create table if not exists insumos (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,
  unidade        text default 'un',
  preco_pacote   numeric(12,2) default 0,   -- quanto voce paga no pacote
  rende          numeric(12,3) default 1,   -- quantas porcoes o pacote rende
  estoque_minimo numeric(12,3) default 0,
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now()
);

create table if not exists produtos (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null,
  preco     numeric(12,2) default 0,
  categoria text default 'Hot dogs',
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists receitas (
  produto_id uuid references produtos(id) on delete cascade,
  insumo_id  uuid references insumos(id)  on delete cascade,
  qtd        numeric(12,3) not null default 1,
  primary key (produto_id, insumo_id)
);

create table if not exists vendas (
  id         uuid primary key default gen_random_uuid(),
  data       date not null default current_date,
  produto_id uuid references produtos(id) on delete set null,
  qtd        numeric(12,2) not null,
  criado_por uuid references auth.users(id),
  criado_em  timestamptz not null default now()
);
create index if not exists idx_vendas_data on vendas(data);

-- Estoque e append-only: cada linha e uma entrada, saida ou ajuste.
-- O saldo e a soma. Assim dois celulares nunca se atropelam.
create table if not exists estoque_lanc (
  id         uuid primary key default gen_random_uuid(),
  insumo_id  uuid references insumos(id) on delete cascade,
  tipo       text not null check (tipo in ('entrada','saida','perda','ajuste')),
  qtd        numeric(12,3) not null,
  obs        text,
  criado_por uuid references auth.users(id),
  criado_em  timestamptz not null default now()
);
create index if not exists idx_estoque_insumo on estoque_lanc(insumo_id);

-- O funcionario avisa daqui o que precisa comprar.
create table if not exists reposicao (
  id           uuid primary key default gen_random_uuid(),
  insumo_id    uuid references insumos(id) on delete cascade,
  qtd          numeric(12,3),
  urgencia     text default 'normal' check (urgencia in ('normal','urgente')),
  obs          text,
  status       text not null default 'aberto' check (status in ('aberto','comprado','cancelado')),
  criado_por   uuid references auth.users(id),
  criado_em    timestamptz not null default now(),
  resolvido_em timestamptz
);

create table if not exists movimentos (
  id         uuid primary key default gen_random_uuid(),
  data       date not null default current_date,
  descricao  text,
  categoria  text,
  tipo       text not null check (tipo in ('entrada','saida')),
  valor      numeric(12,2) not null,
  criado_por uuid references auth.users(id),
  criado_em  timestamptz not null default now()
);

create table if not exists contas_fixas (
  id    uuid primary key default gen_random_uuid(),
  nome  text not null,
  valor numeric(12,2) default 0,
  dia   int
);

create table if not exists dividas (
  id      uuid primary key default gen_random_uuid(),
  nome    text not null,
  saldo   numeric(12,2) default 0,
  parcela numeric(12,2) default 0,
  juros   numeric(6,3)  default 0,
  pago    numeric(12,2) default 0
);

create table if not exists config (
  chave text primary key,
  valor jsonb not null default '{}'::jsonb
);

-- ---------------------------------------------------------------------
-- 3. VISOES PRONTAS (para consultar sem escrever conta na mao)
-- ---------------------------------------------------------------------
create or replace view v_custo_produto with (security_invoker = on) as
select p.id as produto_id, p.nome, p.preco,
       coalesce(sum(r.qtd * case when i.rende > 0 then i.preco_pacote / i.rende else 0 end), 0) as custo,
       p.preco - coalesce(sum(r.qtd * case when i.rende > 0 then i.preco_pacote / i.rende else 0 end), 0) as margem
from produtos p
left join receitas r on r.produto_id = p.id
left join insumos  i on i.id = r.insumo_id
group by p.id, p.nome, p.preco;

create or replace view v_estoque with (security_invoker = on) as
select i.id as insumo_id, i.nome, i.unidade, i.estoque_minimo,
       case when i.rende > 0 then i.preco_pacote / i.rende else 0 end as custo_unitario,
       coalesce(sum(case when e.tipo = 'entrada' then e.qtd else -e.qtd end), 0) as saldo
from insumos i
left join estoque_lanc e on e.insumo_id = i.id
where i.ativo
group by i.id, i.nome, i.unidade, i.estoque_minimo, i.rende, i.preco_pacote;

create or replace view v_vendas_dia with (security_invoker = on) as
select v.data,
       sum(v.qtd)                    as itens,
       sum(v.qtd * c.preco)          as faturamento,
       sum(v.qtd * c.custo)          as custo,
       sum(v.qtd * c.margem)         as margem
from vendas v
join v_custo_produto c on c.produto_id = v.produto_id
group by v.data
order by v.data;

create or replace view v_vendas_mes with (security_invoker = on) as
select to_char(data, 'YYYY-MM') as mes,
       sum(itens) as itens, sum(faturamento) as faturamento,
       sum(custo) as custo, sum(margem) as margem
from v_vendas_dia
group by 1 order by 1;

create or replace view v_ranking_produtos with (security_invoker = on) as
select to_char(v.data,'YYYY-MM') as mes, c.nome,
       sum(v.qtd) as vendidos,
       sum(v.qtd * c.preco)  as faturamento,
       sum(v.qtd * c.margem) as sobrou
from vendas v join v_custo_produto c on c.produto_id = v.produto_id
group by 1,2 order by 1 desc, 5 desc;

-- ---------------------------------------------------------------------
-- 4. SEGURANCA (RLS) — quem pode ver e mexer em que
-- ---------------------------------------------------------------------
alter table perfis       enable row level security;
alter table insumos      enable row level security;
alter table produtos     enable row level security;
alter table receitas     enable row level security;
alter table vendas       enable row level security;
alter table estoque_lanc enable row level security;
alter table reposicao    enable row level security;
alter table movimentos   enable row level security;
alter table contas_fixas enable row level security;
alter table dividas      enable row level security;
alter table config       enable row level security;

do $$
declare t text;
begin
  for t in select unnest(array['perfis','insumos','produtos','receitas','vendas',
                               'estoque_lanc','reposicao','movimentos','contas_fixas','dividas','config'])
  loop
    execute format('drop policy if exists p_sel on %I', t);
    execute format('drop policy if exists p_ins on %I', t);
    execute format('drop policy if exists p_upd on %I', t);
    execute format('drop policy if exists p_del on %I', t);
  end loop;
end $$;

-- PERFIS: cada um ve o proprio; admin ve e edita todos.
create policy p_sel on perfis for select to authenticated using (id = auth.uid() or seg.e_admin());
create policy p_upd on perfis for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on perfis for delete to authenticated using (seg.e_admin());

-- CARDAPIO E INSUMOS: quem esta liberado le; so admin altera.
create policy p_sel on insumos  for select to authenticated using (seg.liberado());
create policy p_ins on insumos  for insert to authenticated with check (seg.e_admin());
create policy p_upd on insumos  for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on insumos  for delete to authenticated using (seg.e_admin());

create policy p_sel on produtos for select to authenticated using (seg.liberado());
create policy p_ins on produtos for insert to authenticated with check (seg.e_admin());
create policy p_upd on produtos for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on produtos for delete to authenticated using (seg.e_admin());

create policy p_sel on receitas for select to authenticated using (seg.liberado());
create policy p_ins on receitas for insert to authenticated with check (seg.e_admin());
create policy p_upd on receitas for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on receitas for delete to authenticated using (seg.e_admin());

-- VENDAS: qualquer liberado lanca; so admin apaga.
create policy p_sel on vendas for select to authenticated using (seg.liberado());
create policy p_ins on vendas for insert to authenticated with check (seg.liberado());
create policy p_upd on vendas for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on vendas for delete to authenticated using (seg.e_admin());

-- ESTOQUE: qualquer liberado registra consumo e reposicao.
create policy p_sel on estoque_lanc for select to authenticated using (seg.liberado());
create policy p_ins on estoque_lanc for insert to authenticated with check (seg.liberado());
create policy p_del on estoque_lanc for delete to authenticated using (seg.e_admin());

create policy p_sel on reposicao for select to authenticated using (seg.liberado());
create policy p_ins on reposicao for insert to authenticated with check (seg.liberado());
create policy p_upd on reposicao for update to authenticated using (seg.liberado()) with check (seg.liberado());
create policy p_del on reposicao for delete to authenticated using (seg.e_admin());

-- FINANCEIRO: SOMENTE ADMIN. O funcionario nem consegue ler.
create policy p_sel on movimentos for select to authenticated using (seg.e_admin());
create policy p_ins on movimentos for insert to authenticated with check (seg.e_admin());
create policy p_upd on movimentos for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on movimentos for delete to authenticated using (seg.e_admin());

create policy p_sel on contas_fixas for select to authenticated using (seg.e_admin());
create policy p_ins on contas_fixas for insert to authenticated with check (seg.e_admin());
create policy p_upd on contas_fixas for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on contas_fixas for delete to authenticated using (seg.e_admin());

create policy p_sel on dividas for select to authenticated using (seg.e_admin());
create policy p_ins on dividas for insert to authenticated with check (seg.e_admin());
create policy p_upd on dividas for update to authenticated using (seg.e_admin()) with check (seg.e_admin());
create policy p_del on dividas for delete to authenticated using (seg.e_admin());

create policy p_sel on config for select to authenticated using (seg.liberado());
create policy p_ins on config for insert to authenticated with check (seg.e_admin());
create policy p_upd on config for update to authenticated using (seg.e_admin()) with check (seg.e_admin());

-- ---------------------------------------------------------------------
-- 5. CONFIGURACAO INICIAL (sem numeros inventados — tudo em branco)
-- ---------------------------------------------------------------------
insert into config (chave, valor) values
  ('geral', '{"caixa":null,"retirada":null,"dias":null,"caixaMin":null,"margemMin":null}'::jsonb)
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------
-- PRONTO.
-- Agora volte ao painel, crie SUA conta primeiro (voce vira admin
-- automaticamente) e so depois mande os funcionarios se cadastrarem.
-- ---------------------------------------------------------------------
