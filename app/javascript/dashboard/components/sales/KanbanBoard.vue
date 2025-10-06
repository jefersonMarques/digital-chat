<template>
  <div class="kanban">
    <div class="toolbar" ref="toolbarEl">
      <div class="right">
        <label style="margin-right:8px">Pipeline:</label>
        <select v-model="selectedPipelineId">
          <option v-for="p in pipelines" :key="p.id" :value="String(p.id)">{{ p.name }}</option>
        </select>
      </div>
    </div>

    <div v-if="loading" style="padding:16px">Carregando...</div>
    <div v-else-if="error" style="padding:16px; color:#b91c1c">Erro: {{ errorMessage }}</div>

    <!-- Scroll horizontal via grab; wheel horizontal bloqueado no handler -->
    <div v-else ref="columnsEl" class="columns" :style="columnsStyle" :class="{ panning: pan.isDown }"
      @pointerdown="onPanPointerDown" @pointermove="onPanPointerMove" @pointerup="onPanPointerUp"
      @pointercancel="onPanPointerUp">
      <div class="column" v-for="(s, idx) in stages" :key="s.id" :class="{ 'is-last': idx === stages.length - 1 }">
        <header class="col-header">
          <div class="col-title">
            {{ s.name }}
            <span class="count">({{ (dealsByStage[s.id] || []).length }})</span>
          </div>

          <!-- Agora abre o Dialog unificado via SalesViewSwitcher -->
          <button class="add-btn" title="Adicionar lead" aria-label="Adicionar lead"
            @click.stop="$emit('open-new-lead', { preselectStageId: s.id })">
            <span class="i-lucide-plus" aria-hidden="true"></span>
          </button>
        </header>

        <div class="cards" :class="{
          'drop-over': dnd.overStageId === s.id,
          'drop-over--won': dnd.overStageId === s.id && isWonStage(s),
          'drop-over--lost': dnd.overStageId === s.id && isLostStage(s),
        }" @dragover.prevent="onColumnDragOver(s.id, $event)" @dragenter.prevent="onColumnDragEnter(s.id)"
          @dragleave.prevent="onColumnDragLeave(s.id)" @drop.prevent="onColumnDrop(s.id, $event)">
          <div class="card" v-for="d in (dealsByStage[s.id] || [])" :key="d.id" draggable="true"
            @dragstart="onCardDragStart(d, s.id, $event)" @dragend="onCardDragEnd($event)">
            <div class="title">{{ d.title }}</div>
            <div class="meta">
              <div>Valor: {{ formatBRL(d.amount_cents) }}</div>
              <div>ID: #{{ d.id }}</div>
            </div>
          </div>

          <div v-if="(dealsByStage[s.id] || []).length === 0" class="empty">Sem negócios</div>
        </div>
      </div>

      <div class="gutter" aria-hidden="true" />
    </div>
  </div>
</template>

<script>
// axios global do Chatwoot
function http() {
  const ax = typeof window !== 'undefined' ? window.axios : null;
  if (!ax) throw new Error('HTTP do Chatwoot indisponível');
  return ax;
}

export default {
  name: 'KanbanBoard',
  props: { accountId: { type: [String, Number], required: false } },
  data() {
    return {
      accountIdResolved: null,
      loading: true,
      error: null,
      pipelines: [],
      selectedPipelineId: null,
      stages: [],
      dealsByStage: {},

      // layout
      viewportH: window.innerHeight,

      // pan horizontal (grab)
      pan: { isDown: false, startX: 0, startScrollLeft: 0, pid: null },

      // drag & drop
      dnd: { draggedDeal: null, fromStageId: null, overStageId: null },

      // handler do wheel no container de colunas
      _columnsWheelHandler: null,
    };
  },
  computed: {
    errorMessage() {
      const e = this.error;
      if (!e) return '';
      if (typeof e === 'string') return e;
      if (e.message) return e.message;
      if (e.errors) return Array.isArray(e.errors) ? e.errors.join(', ') : String(e.errors);
      try { return JSON.stringify(e); } catch { return String(e); }
    },
    columnsStyle() {
      const toolbarH = this.$refs.toolbarEl?.offsetHeight || 56;
      const gutter = 'clamp(56px, 12vw, 350px)';
      const h = Math.max(350, this.viewportH - toolbarH - 24);
      return { '--kanban-gutter': gutter, height: `${h}px` };
    },
  },
  async mounted() {
    try {
      window.addEventListener('resize', this.onResize);

      const fromRoute = this.$route?.params?.accountId;
      const fromProp = this.accountId;
      const fromStore = this.$store?.getters?.getCurrentUser?.account_id;
      this.accountIdResolved = String(fromRoute || fromProp || fromStore || '').trim();
      if (!this.accountIdResolved) throw new Error('Não foi possível resolver o accountId.');

      await this.loadPipelines();
      if (this.pipelines.length) this.selectedPipelineId = String(this.pipelines[0].id);
      await this.loadStages();
      await this.fetchDeals();
      this.ensureStageBuckets();

      // Listener do wheel para bloquear horizontal
      this._columnsWheelHandler = this.columnsWheelHandler.bind(this);
      const el = this.getColumnsEl();
      if (el && el.addEventListener) {
        el.addEventListener('wheel', this._columnsWheelHandler, { passive: false, capture: true });
      }
    } catch (e) {
      this.error = e?.response?.data || e?.message || e;
    } finally {
      this.loading = false;
    }
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.onResize);
    const el = this.getColumnsEl();
    if (el && this._columnsWheelHandler) {
      el.removeEventListener('wheel', this._columnsWheelHandler, { capture: true });
    }
  },
  watch: {
    async selectedPipelineId(val) {
      if (!val) return;
      this.loading = true;
      try {
        await this.loadStages();
        await this.fetchDeals();
        this.ensureStageBuckets();
      } catch (e) {
        this.error = e?.response?.data || e?.message || e;
      } finally {
        this.loading = false;
      }
    },
  },
  methods: {
    // ==== Integração com o diálogo unificado (SalesViewSwitcher) ====
    async getNewLeadContext() {
      return {
        accountId: this.accountIdResolved,
        pipelineId: String(this.selectedPipelineId),
        stages: this.stages,
      };
    },
    onLeadCreated(created) {
      const sid = created?.deal_stage_id;
      if (sid == null) return;
      const bucket = Array.isArray(this.dealsByStage[sid]) ? this.dealsByStage[sid] : [];
      this.dealsByStage = { ...this.dealsByStage, [sid]: [created, ...bucket] };
    },

    // ---------- HTTP ----------
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
      try {
        const { data } = await http().get(
          `/api/v1/accounts/${this.accountIdResolved}/deals`,
          { params: { deal_pipeline_id: this.selectedPipelineId, status: 'open' } }
        );
        this.mapDealsByStage(Array.isArray(data) ? data : []);
      } catch (e) {
        if (e?.response?.status === 404) {
          const results = await Promise.all(
            (this.stages || []).map(s =>
              http()
                .get(`/api/v1/accounts/${this.accountIdResolved}/deal_pipelines/${this.selectedPipelineId}/deal_stages/${s.id}/deals`)
                .then(r => ({ stageId: s.id, data: Array.isArray(r.data) ? r.data : [] }))
                .catch(() => ({ stageId: s.id, data: [] }))
            )
          );
          const map = {};
          results.forEach(({ stageId, data }) => { map[stageId] = data; });
          this.dealsByStage = map;
          this.ensureStageBuckets();
        } else {
          throw e;
        }
      }
    },
    mapDealsByStage(deals) {
      const map = {};
      this.ensureStageBuckets();
      deals.forEach(d => {
        (map[d.deal_stage_id] = map[d.deal_stage_id] || []).push(d);
      });
      this.dealsByStage = map;
    },
    async updateDealStage(dealId, newStageId) {
      return http().patch(
        `/api/v1/accounts/${this.accountIdResolved}/deals/${dealId}`,
        { deal_stage_id: newStageId }
      );
    },

    // ---------- PAN (grab para eixo X) ----------
    onResize() { this.viewportH = window.innerHeight; },
    getColumnsEl() { return this.$refs.columnsEl; },
    onPanPointerDown(e) {
      if (e.button !== 0) return;
      if (e.target?.closest('.card')) return;
      if (e.target?.closest('.add-btn')) return;
      const el = this.getColumnsEl();
      if (!el) return;
      this.pan.isDown = true;
      this.pan.pid = e.pointerId;
      this.pan.startX = e.clientX;
      this.pan.startScrollLeft = el.scrollLeft;
      el.classList.add('no-select');
      try { el.setPointerCapture(e.pointerId); } catch (_) { }
    },
    onPanPointerMove(e) {
      if (!this.pan.isDown || e.pointerId !== this.pan.pid) return;
      const el = this.getColumnsEl();
      if (!el) return;
      const dx = e.clientX - this.pan.startX;
      el.scrollLeft = this.pan.startScrollLeft - dx;
    },
    onPanPointerUp(e) {
      if (e.pointerId !== this.pan.pid) return;
      this.pan.isDown = false;
      this.pan.pid = null;
      const el = this.getColumnsEl();
      el?.classList.remove('no-select');
    },

    ensureStageBuckets() {
      const stages = Array.isArray(this.stages) ? this.stages : [];
      const next = { ...this.dealsByStage };

      // garante um bucket (array) para cada estágio visível
      stages.forEach(s => {
        if (!Array.isArray(next[s.id])) next[s.id] = [];
      });

      // remove buckets de estágios que não existem mais
      Object.keys(next).forEach(k => {
        const exists = stages.some(s => String(s.id) === String(k));
        if (!exists) delete next[k];
      });

      this.dealsByStage = next;
    },

    // ---------- DnD ----------
    onCardDragStart(deal, stageId, evt) {
      this.dnd.draggedDeal = deal;
      this.dnd.fromStageId = stageId;
      evt.dataTransfer?.setData('text/plain', String(deal.id));
      evt.dataTransfer && (evt.dataTransfer.effectAllowed = 'move');
      evt.target?.classList?.add('dragging');
    },
    onCardDragEnd(evt) {
      evt.target?.classList?.remove('dragging');
      this.dnd.draggedDeal = null;
      this.dnd.fromStageId = null;
      this.dnd.overStageId = null;
    },
    onColumnDragEnter(stageId) { this.dnd.overStageId = stageId; },
    onColumnDragLeave(stageId) { if (this.dnd.overStageId === stageId) this.dnd.overStageId = null; },
    onColumnDragOver(_stageId, evt) { evt.dataTransfer && (evt.dataTransfer.dropEffect = 'move'); },
    async onColumnDrop(targetStageId) {
      const deal = this.dnd.draggedDeal;
      const fromStageId = this.dnd.fromStageId;
      this.dnd.overStageId = null;
      if (!deal || fromStageId == null || targetStageId == null || fromStageId === targetStageId) return;

      const prev = JSON.parse(JSON.stringify(this.dealsByStage));
      try {
        const fromArr = (this.dealsByStage[fromStageId] || []).filter(x => x.id !== deal.id);
        const moved = { ...deal, deal_stage_id: targetStageId };
        const toArr = [moved, ...(this.dealsByStage[targetStageId] || [])];
        this.dealsByStage = { ...this.dealsByStage, [fromStageId]: fromArr, [targetStageId]: toArr };
        await this.updateDealStage(deal.id, targetStageId);
      } catch (e) {
        this.dealsByStage = prev;
        this.error = e?.response?.data || e?.message || e;
      }
    },

    // ---------- Utils ----------
    formatBRL(cents) {
      if (typeof cents !== 'number') return '-';
      return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    },
    isWonStage(s) {
      const tag = String(s.status || s.state || s.kind || '').toLowerCase();
      const name = String(s.name || s.title || '').toLowerCase();
      return (
        tag === 'won' ||
        name.includes('ganh') ||
        /(^|\s)(won|win)(\s|$)/.test(name)
      );
    },
    isLostStage(s) {
      const tag = String(s.status || s.state || s.kind || '').toLowerCase();
      const name = String(s.name || s.title || '').toLowerCase();
      return (
        tag === 'lost' ||
        name.includes('perd') ||
        /(^|\s)(lost|lose)(\s|$)/.test(name)
      );
    },

    // ---------- Wheel: bloquear eixo X por roda/trackpad ----------
    columnsWheelHandler(e) {
      if (this.pan.isDown) return; // grab controla X
      const absX = Math.abs(e.deltaX || 0);
      const absY = Math.abs(e.deltaY || 0);
      const horizontalIntent = e.shiftKey || absX > absY;
      if (horizontalIntent) {
        e.preventDefault(); // impede deslocamento horizontal por wheel
      }
    },
  },
};
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
  background: #fff
}

/* Container horizontal: scroll X só via grab (wheel X bloqueado) */
.columns {
  width: 100vw;
  display: flex;
  gap: 12px;
  padding: 12px;
  overflow-x: auto;
  overflow-y: hidden;
  cursor: grab;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior-x: contain;
  touch-action: pan-y;
  scrollbar-gutter: stable both-edges;
}

.column.is-last {
  margin-right: 25px;
}

.columns>.column:last-of-type {
  margin-right: 25px;
}

.columns.panning {
  cursor: grabbing
}

.no-select {
  user-select: none
}

.gutter {
  flex: 0 0 var(--kanban-gutter);
}

.column {
  min-width: 300px;
  background: #fafafa;
  border: 1px solid #eee;
  border-radius: 10px;
  display: flex;
  flex-direction: column
}

.col-header {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: space-between;
  padding: 10px 12px;
  border-bottom: 1px solid #eee
}

.col-title {
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 6px
}

.count {
  font-weight: 500;
  color: #6b7280;
  font-size: 12px
}

.add-btn {
  display: inline-grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 9999px;
  background: #f6f7f9;
  border: 1px solid #e5e7eb;
  color: #111827;
  opacity: .85;
  transition: all .12s ease;
}

.add-btn:hover {
  opacity: 1;
  background: #f1f5f9
}

.add-btn:active {
  transform: translateY(1px)
}

.add-btn .i-lucide-plus {
  font-size: 16px;
  line-height: 1
}

.cards {
  padding: 10px;
  overflow-y: auto;
  min-height: 80px;
  transition: background 120ms;
  flex: 1 1 auto
}

.cards.drop-over {
  background: rgba(59, 130, 246, 0.08);
  outline: 1px dashed rgba(59, 130, 246, 0.35);
  outline-offset: 2px;
  border-radius: 8px
}

.card {
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 10px;
  margin-bottom: 10px;
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.04);
  cursor: grab
}

.card.dragging {
  opacity: .6;
  box-shadow: 0 4px 16px rgba(0, 0, 0, .15)
}

.card .title {
  font-weight: 600;
  margin-bottom: 4px
}

.card .meta {
  font-size: 12px;
  color: #6b7280;
  display: flex;
  justify-content: space-between
}

.empty {
  color: #9ca3af;
  font-size: 12px;
  padding: 8px;
  text-align: center
}

/* Verde ao arrastar sobre "Ganho" */
.cards.drop-over.drop-over--won {
  background: rgba(16, 185, 129, 0.12);
  outline-color: rgba(16, 185, 129, 0.50);
}

/* Vermelho ao arrastar sobre "Perdido" */
.cards.drop-over.drop-over--lost {
  background: rgba(239, 68, 68, 0.12);
  outline-color: rgba(239, 68, 68, 0.50);
}
</style>
