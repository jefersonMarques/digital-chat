<template>
  <div class="deals-table">
    <!-- Toolbar (mantive seu HTML) -->
    <div class="table-toolbar px-6 pt-4">
      <div class="right flex flex-wrap items-center gap-3">
        <label class="whitespace-nowrap text-sm font-medium mr-1">Pipeline:</label>

        <!-- ComboBox recebe classes no root; ajuste w-56 / md:w-64 conforme quiser -->
        <ComboBox class="w-56 md:w-64" v-model="selectedPipelineId" :options="pipelinesOptions"
          placeholder="Escolha um pipeline" search-placeholder="Procure pelo nome" @select="onPipelineSelect" />

        <label class="whitespace-nowrap text-sm font-medium ml-2">Estágio:</label>

        <ComboBox class="w-44 md:w-48" v-model="stageFilter" :options="stagesOptions" placeholder="Todos"
          search-placeholder="Procure pelo estágio" @select="onStageSelect" />

        <!-- input que cresce ocupando o espaço restante -->
        <Input v-model="q" :customInputClass="'flex-1 min-w-[180px] w-full md:w-auto'"
          placeholder="Buscar por título/contato..." @enter="onSearchInput" />
      </div>
    </div>

    <div v-if="loading" style="padding:16px">Carregando...</div>
    <div v-else-if="error" style="padding:16px; color:#b91c1c">Erro: {{ errorMessage }}</div>

    <!-- Lista de cards (substitui a tabela) -->
    <div v-else class="table-wrap">
      <LeadsList :leads="visibleRows" :pipelines="pipelines" :stages="stages" :account-id="accountIdResolved" />
      <div v-if="!visibleRows.length" class="p-6 text-center text-sm text-n-slate-11">Nenhum registro</div>
    </div>
  </div>
</template>

<script>
import LeadsList from './LeadsList.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue'; // seu Input.vue

// axios global do Chatwoot
function http() {
  const ax = typeof window !== 'undefined' ? window.axios : null;
  if (!ax) throw new Error('HTTP do Chatwoot indisponível');
  return ax;
}

export default {
  name: 'DealsTable',
  components: { LeadsList, ComboBox, Input },
  props: { accountId: { type: [String, Number], required: false } },
  data() {
    return {
      accountIdResolved: null,
      loading: true,
      error: null,
      pipelines: [],
      selectedPipelineId: null,
      stages: [],
      deals: [],

      // filtros/sort
      q: '',
      stageFilter: '',
      sort: { key: 'updated_at', dir: 'desc' },
    };
  },
  computed: {
    // mapeia pipelines para o formato esperado pelo ComboBox
    pipelinesOptions() {
      return (this.pipelines || []).map(p => ({
        value: String(p.id),
        label: p.name || String(p.id)
      }));
    },

    // stagesOptions inclui 'Todos' como primeira opção
    stagesOptions() {
      const base = (this.stages || []).map(s => ({
        value: String(s.id),
        label: s.name || String(s.id),
      }));
      return [{ value: '', label: 'Todos' }, ...base];
    },

    errorMessage() {
      const e = this.error;
      if (!e) return '';
      if (typeof e === 'string') return e;
      if (e.message) return e.message;
      if (e.errors) return Array.isArray(e.errors) ? e.errors.join(', ') : String(e.errors);
      try { return JSON.stringify(e); } catch { return String(e); }
    },
    filtered() {
      let rows = this.deals.slice();

      if (this.stageFilter) {
        rows = rows.filter(d => String(d.deal_stage_id) === String(this.stageFilter));
      }

      if (this.q) {
        const term = this.q.toLowerCase();
        rows = rows.filter(d =>
          (d.title || '').toLowerCase().includes(term) ||
          (d.contact_name || '').toLowerCase().includes(term) ||
          (d.contact_email || '').toLowerCase().includes(term) ||
          (d.contact_phone || '').toLowerCase().includes(term)
        );
      }

      return rows;
    },
    visibleRows() {
      const rows = this.filtered;
      const { key, dir } = this.sort;
      const sign = dir === 'asc' ? 1 : -1;

      return rows.slice().sort((a, b) => {
        let va = a[key], vb = b[key];
        // padroniza
        if (key === 'amount_cents') {
          va = typeof va === 'number' ? va : -1;
          vb = typeof vb === 'number' ? vb : -1;
        } else if (key === 'updated_at') {
          va = va ? new Date(va).getTime() : 0;
          vb = vb ? new Date(vb).getTime() : 0;
        } else if (key === 'deal_stage_id') {
          va = String(va); vb = String(vb);
        } else {
          va = (va || '').toString().toLowerCase();
          vb = (vb || '').toString().toLowerCase();
        }
        if (va < vb) return -1 * sign;
        if (va > vb) return 1 * sign;
        return 0;
      });
    },
  },
  async mounted() {
    try {
      const fromRoute = this.$route?.params?.accountId;
      const fromProp = this.accountId;
      const fromStore = this.$store?.getters?.getCurrentUser?.account_id;
      this.accountIdResolved = String(fromRoute || fromProp || fromStore || '').trim();
      if (!this.accountIdResolved) throw new Error('Não foi possível resolver o accountId.');

      await this.loadPipelines();
      if (this.pipelines.length) this.selectedPipelineId = String(this.pipelines[0].id);
      await this.loadStages();
      await this.fetchDeals();
    } catch (e) {
      this.error = e?.response?.data || e?.message || e;
    } finally {
      this.loading = false;
    }
  },
  watch: {
    async selectedPipelineId(val) {
      if (!val) return;
      this.loading = true;
      try {
        await this.loadStages();
        await this.fetchDeals();
        this.stageFilter = '';
      } catch (e) {
        this.error = e?.response?.data || e?.message || e;
      } finally {
        this.loading = false;
      }
    },
  },
  methods: {
    // quando ComboBox emite select (objeto) definimos selectedPipelineId (dispara a watch)
    onPipelineSelect(opt) {
      if (!opt) return;
      this.selectedPipelineId = String(opt.value);
    },

    // quando selecionam stage via ComboBox definimos stageFilter
    onStageSelect(opt) {
      // opt.value pode ser '' (Todos)
      this.stageFilter = String(opt?.value ?? '');
    },

    // === Integração com o dialog unificado (SalesViewSwitcher) ===
    async getNewLeadContext() {
      return {
        accountId: this.accountIdResolved,
        pipelineId: String(this.selectedPipelineId),
        stages: this.stages,
        allowStageSelect: true,
        preselectStageId: null,
      };
    },
    onLeadCreated(created) {
      this.deals = [this.hydrateContactFields(created), ...this.deals];
    },

    // ------- HTTP -------
    async loadPipelines() {
      const { data } = await http().get(`/api/v1/accounts/${this.accountIdResolved}/deal_pipelines`);
      this.pipelines = Array.isArray(data) ? data : [];
    },
    async loadStages() {
      const { data } = await http().get(
        `/api/v1/accounts/${this.accountIdResolved}/deal_pipelines/${this.selectedPipelineId}/deal_stages`
      );
      this.stages = Array.isArray(data) ? data : [];
    },
    async fetchDeals() {
      // tenta endpoint agregado
      try {
        const { data } = await http().get(
          `/api/v1/accounts/${this.accountIdResolved}/deals`,
          { params: { deal_pipeline_id: this.selectedPipelineId, status: 'open' } }
        );
        const arr = Array.isArray(data) ? data : [];
        this.deals = arr.map(this.hydrateContactFields);
      } catch (e) {
        // fallback por estágio
        if (e?.response?.status === 404) {
          const results = await Promise.all(
            (this.stages || []).map(s =>
              http()
                .get(`/api/v1/accounts/${this.accountIdResolved}/deal_pipelines/${this.selectedPipelineId}/deal_stages/${s.id}/deals`)
                .then(r => Array.isArray(r.data) ? r.data : [])
                .catch(() => [])
            )
          );
          this.deals = results.flat().map(this.hydrateContactFields);
        } else {
          throw e;
        }
      }
    },
    hydrateContactFields(d) {
      // muitas instalações do Chatwoot retornam contato aninhado
      const c = d.contact || d.contact_inbox || {};
      return {
        ...d,
        contact_name: d.contact_name || c.name || '',
        contact_email: d.contact_email || c.email || '',
        contact_phone: d.contact_phone || c.phone_number || '',
      };
    },

    // ------- Busca/Sort -------
    onSearchInput() { /* computed reage */ },
    toggleSort(key) {
      if (this.sort.key === key) {
        this.sort.dir = this.sort.dir === 'asc' ? 'desc' : 'asc';
      } else {
        this.sort.key = key;
        this.sort.dir = 'asc';
      }
    },

    stageName(id) {
      const s = this.stages.find(x => String(x.id) === String(id));
      return s ? s.name : '—';
    },
    stageClass(id) {
      const s = this.stages.find(x => String(x.id) === String(id));
      if (!s) return '';
      const name = String(s.name || '').toLowerCase();
      if (name.includes('ganh') || /(^|\s)(won|win)(\s|$)/.test(name)) return 'won';
      if (name.includes('perd') || /(^|\s)(lost|lose)(\s|$)/.test(name)) return 'lost';
      return '';
    },

    // ------- Utils -------
    formatBRL(cents) {
      if (typeof cents !== 'number') return '-';
      return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    },
    formatDateTime(iso) {
      if (!iso) return '—';
      try {
        const d = new Date(iso);
        return d.toLocaleString('pt-BR');
      } catch { return '—'; }
    },
  },
};
</script>

<style scoped>
/* mantive o CSS original (pode colar o seu existente aqui) */
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
  background: #fff
}

.right {
  display: flex;
  align-items: center;
  gap: 8px
}

.search {
  height: 32px;
  padding: 0 10px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  outline: none;
}

.primary {
  height: 32px;
  padding: 0 12px;
  border-radius: 8px;
  border: 1px solid #0ea5e9;
  background: #0ea5e9;
  color: #fff;
  font-weight: 600;
}

.table-wrap {
  width: 100%;
  overflow: auto;
}
</style>
