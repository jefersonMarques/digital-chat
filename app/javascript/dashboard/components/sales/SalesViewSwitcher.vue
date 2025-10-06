<template>
  <div class="flex flex-col min-w-0 max-w-full w-full">
    <!-- Top bar -->
    <div class="sticky top-0 z-10 flex items-center justify-between gap-2 p-3 md:p-4 bg-white border-b border-n-weak">
      <!-- Segmented control -->
      <div class="inline-flex items-center gap-0.5 rounded-xl p-0.5 bg-n-alpha-2 border border-n-weak max-w-full overflow-x-auto">
        <button
          :class="[
            'px-3 py-1.5 rounded-lg font-semibold whitespace-nowrap border transition',
            'text-n-slate-11 border-transparent hover:bg-white hover:border-n-weak focus:outline-none focus:ring-2 focus:ring-n-slate-7/40',
            mode === 'kanban' ? 'bg-white border-n-weak text-n-slate-12 shadow' : ''
          ]"
          :aria-pressed="mode === 'kanban'"
          @click="setMode('kanban')"
        >
          Kanban
        </button>
        <button
          :class="[
            'px-3 py-1.5 rounded-lg font-semibold whitespace-nowrap border transition',
            'text-n-slate-11 border-transparent hover:bg-white hover:border-n-weak focus:outline-none focus:ring-2 focus:ring-n-slate-7/40',
            mode === 'table' ? 'bg-white border-n-weak text-n-slate-12 shadow' : ''
          ]"
          :aria-pressed="mode === 'table'"
          @click="setMode('table')"
        >
          Tabela
        </button>
      </div>

      <!-- Botão Novo lead (usa Button do Chatwoot) -->
      <Button
        color="blue"
        :label="'Novo lead'"
        class="h-8"
        @click="openNewLeadFromSwitcher"
      />
    </div>

    <!-- Conteúdo -->
    <div class="min-w-0 overflow-x-hidden grid grid-cols-1">
      <component
        :is="mode === 'kanban' ? 'KanbanBoard' : 'DealsTable'"
        :account-id="accountId"
        ref="activeView"
        @open-new-lead="openNewLeadFromChild"
      />
    </div>

    <!-- Dialog unificado -->
    <NewLeadDialog
      ref="newLeadDialog"
      :account-id="accountId"
      @created="onLeadCreated"
    />
  </div>
</template>

<script>
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanBoard from 'dashboard/components/sales/KanbanBoard.vue';
import DealsTable from 'dashboard/components/sales/DealsTable.vue';
import NewLeadDialog from 'dashboard/components/sales/NewLeadDialog.vue';

export default {
  name: 'SalesViewSwitcher',
  components: { Button, KanbanBoard, DealsTable, NewLeadDialog },
  props: { accountId: { type: [String, Number], required: false } },
  data() {
    return { mode: 'kanban' };
  },
  mounted() {
    const saved = localStorage.getItem('sales:viewMode');
    if (saved === 'kanban' || saved === 'table') this.mode = saved;
  },
  methods: {
    setMode(m) {
      this.mode = m;
      localStorage.setItem('sales:viewMode', m);
    },

    async openNewLeadFromSwitcher() {
      // Abre o diálogo unificado. Ele mesmo carrega pipeline/estágios.
      this.$refs.newLeadDialog?.open?.();
    },

    async openNewLeadFromChild(payload) {
      // Caso no futuro o Kanban/Tabela emitam preselect do estágio:
      this.$refs.newLeadDialog?.open?.(payload?.preselectStageId || null);
    },

    onLeadCreated(deal) {
      // Se a view ativa expuser hook, atualiza sem refetch
      this.$refs.activeView?.onLeadCreated?.(deal);
    },
  },
};
</script>
