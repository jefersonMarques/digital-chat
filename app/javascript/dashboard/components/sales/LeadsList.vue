<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';

import LeadsCard from 'dashboard/components/sales/LeadsCard.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  leads: { type: Array, required: true },
  pipelines: { type: Array, default: () => [] }, // [{id, name}]
  stages: { type: Array, default: () => [] },    // [{id, name}]
  accountId: { type: [String, Number], default: null },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const route = useRoute();

const uiFlags = useMapGetter('deals/getUIFlags') || useMapGetter('leads/getUIFlags');
const isUpdating = computed(() => uiFlags.value?.isUpdating || false);
const expandedCardId = ref(null);

const toggleExpanded = id => {
  expandedCardId.value = expandedCardId.value === id ? null : id;
};

const pipelineMap = computed(() => {
  const m = new Map();
  (props.pipelines || []).forEach(p => m.set(String(p.id), p.name || String(p.id)));
  return m;
});
const stageMap = computed(() => {
  const m = new Map();
  (props.stages || []).forEach(s => m.set(String(s.id), s.name || String(s.id)));
  return m;
});

const pipelineName = pid => pipelineMap.value.get(String(pid)) || '—';
const stageName = sid => stageMap.value.get(String(sid)) || '—';

// ===== Navegação (robusta com fallbacks) =====
const pushSafe = async (candidates) => {
  for (const c of candidates) {
    try {
      await router.push(c);
      return true;
    } catch (_) { }
  }
  return false;
};

const onClickViewDetails = async id => {
  const q = route.query || {};
  const ok = await pushSafe([
    { name: 'deals_edit', params: { dealId: id }, query: q },
    { name: 'deals_show', params: { dealId: id }, query: q },
    { name: 'leads_edit', params: { leadId: id }, query: q },
    { name: 'leads_show', params: { leadId: id }, query: q },
  ]);
  if (!ok) {
    try { await router.push({ name: 'deals_edit', params: { dealId: id }, query: q }); } catch (_) { }
  }
};

const openContactDetails = async (lead) => {
  const q = { ...route.query };
  const cid = lead.contact_id || lead.contactId || lead.contact?.id || null;
  if (!cid) return;
  const aid = props.accountId || route.params?.accountId;

  const ok = await pushSafe([
    { name: 'contacts_show', params: { accountId: aid, contactId: cid }, query: q },
    { name: 'contacts_view', params: { accountId: aid, id: cid }, query: q },
    { name: 'crm_contacts_show', params: { contactId: cid }, query: q },
  ]);

  if (!ok && aid) {
    // fallback direto por path comum do Chatwoot
    window.open(`/app/accounts/${aid}/contacts/${cid}`, '_blank');
  }
};

const openChatWithContact = async (lead) => {
  const q = { ...route.query };
  const cid = lead.contact_id || lead.contactId || lead.contact?.id || null;
  if (!cid) return;
  const aid = props.accountId || route.params?.accountId;

  // tenta algumas rotas comuns; se não rolar, abre a página do contato (onde dá pra iniciar conversa)
  const ok = await pushSafe([
    { name: 'contacts_show', params: { accountId: aid, contactId: cid }, query: { ...q, open: 'chat' } },
    { name: 'conversations_list', params: { accountId: aid }, query: { ...q, contact_id: cid } },
  ]);

  if (!ok && aid) {
    window.open(`/app/accounts/${aid}/contacts/${cid}#conversations`, '_blank');
  }
};

const openWhatsApp = (lead) => {
  const raw = (lead.contact_phone || lead.contactPhone || '').toString();
  const digits = raw.replace(/\D+/g, '');
  if (!digits) return;
  const msg = encodeURIComponent('Olá! Podemos falar sobre seu atendimento?');
  window.open(`https://wa.me/${digits}?text=${msg}`, '_blank');
};

const openEmail = (lead) => {
  const mail = (lead.contact_email || lead.contactEmail || '').toString().trim();
  if (!mail) return;
  const subject = encodeURIComponent('Atendimento');
  const body = encodeURIComponent('Olá,\n\nPodemos dar continuidade por aqui?\n');
  window.location.href = `mailto:${mail}?subject=${subject}&body=${body}`;
};

const updateLead = async updatedData => {
  try {
    if (store.dispatch) {
      try {
        await store.dispatch('deals/update', updatedData);
      } catch (e) {
        await store.dispatch('leads/update', updatedData);
      }
    }
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE') || 'Atualizado com sucesso');
  } catch (error) {
    const i18nPrefix = 'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM';
    const DuplicateContactException = window?.DuplicateContactException;
    const ExceptionWithMessage = window?.ExceptionWithMessage;

    if (DuplicateContactException && error instanceof DuplicateContactException) {
      if (error.data.includes('email')) {
        useAlert(t(`${i18nPrefix}.EMAIL_ADDRESS.DUPLICATE`));
      } else if (error.data.includes('phone_number')) {
        useAlert(t(`${i18nPrefix}.PHONE_NUMBER.DUPLICATE`));
      }
    } else if (ExceptionWithMessage && error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t(`${i18nPrefix}.ERROR_MESSAGE`) || (error.message || String(error)));
    }
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 px-6 pt-4 pb-6">
    <div v-for="lead in leads" :key="lead.id" class="flex flex-col gap-1">
      <LeadsCard v-for="lead in leads" :key="lead.id" :id="lead.id" :title="lead.title"
        :contact-id="lead.contact_id || lead.contactId" :contact-name="lead.contact_name || lead.contactName"
        :contact-email="lead.contact_email || lead.contactEmail"
        :contact-phone="lead.contact_phone || lead.contactPhone" :amount-cents="lead.amount_cents || lead.amountCents"
        :deal-pipeline-id="lead.deal_pipeline_id || lead.dealPipelineId"
        :deal-stage-id="lead.deal_stage_id || lead.dealStageId" :updated-at="lead.updated_at || lead.updatedAt"
        :thumbnail="lead.thumbnail"
        :pipeline-label="pipelines.find(p => String(p.id) === String(lead.deal_pipeline_id))?.name || ''"
        :stage-label="stages.find(s => String(s.id) === String(lead.deal_stage_id))?.name || ''"
        :is-expanded="expandedCardId === lead.id" :is-updating="isUpdating" @toggle="toggleExpanded(lead.id)"
        @update-lead="updateLead" />
      
    </div>
  </div>
</template>

<style scoped>
/* minimal; layout herdado */
</style>
