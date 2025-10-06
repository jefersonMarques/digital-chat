<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  id: { type: [Number, String], required: true },
  title: { type: String, default: '' },

  contactId: { type: [Number, String, null], default: null },
  contactName: { type: String, default: '' },
  contactEmail: { type: String, default: '' },
  contactPhone: { type: String, default: '' },

  amountCents: { type: [Number, null], default: null },
  dealPipelineId: { type: [Number, String, null], default: null },
  dealStageId: { type: [Number, String, null], default: null },
  pipelineLabel: { type: String, default: '' },
  stageLabel: { type: String, default: '' },

  updatedAt: { type: String, default: '' },
  thumbnail: { type: String, default: '' },

  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  additionalAttributes: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['toggle', 'update-lead', 'show-lead']);

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

/** ======= estado editável (expand) ======= */
const leadData = ref({
  id: props.id,
  title: props.title,
  contactName: props.contactName,
  contactEmail: props.contactEmail,
  contactPhone: props.contactPhone,
  amountCents: props.amountCents,
  dealStageId: props.dealStageId,
});
watch(
  () => [
    props.title, props.contactName, props.contactEmail,
    props.contactPhone, props.amountCents, props.dealStageId
  ],
  () => {
    leadData.value = {
      id: props.id,
      title: props.title,
      contactName: props.contactName,
      contactEmail: props.contactEmail,
      contactPhone: props.contactPhone,
      amountCents: props.amountCents,
      dealStageId: props.dealStageId,
    };
  }
);

/** ======= formatações ======= */
const formattedAmount = computed(() => {
  const c = leadData.value.amountCents;
  if (typeof c !== 'number') return '—';
  return (c / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
});
const formattedDate = computed(() => {
  if (!props.updatedAt) return '—';
  try { return new Date(props.updatedAt).toLocaleString('pt-BR'); }
  catch { return props.updatedAt; }
});
const displayPipeline = computed(() => props.pipelineLabel || String(props.dealPipelineId || '—'));
const displayStage = computed(() => props.stageLabel || String(props.dealStageId || '—'));

/** badge por “intenção” do estágio (ganho/perdido/etc) */
const stageTone = computed(() => {
  const s = (props.stageLabel || '').toLowerCase();
  if (s.match(/ganh|won|win/)) return 'won';
  if (s.match(/perd|lost|lose/)) return 'lost';
  return 'neutral';
});
const stageClasses = computed(() => {
  if (stageTone.value === 'won')   return 'bg-n-teal-9/10 text-n-teal-11';
  if (stageTone.value === 'lost')  return 'bg-n-ruby-9/10 text-n-ruby-11';
  return 'bg-n-alpha-2 text-n-slate-11 dark:bg-n-alpha-2';
});

/** ======= ações ======= */
const onClickExpand = () => emit('toggle');
const onClickViewDetails = () => emit('show-lead', props.id);

const openContactDetails = async () => {
  const aid = route.params?.accountId;
  const cid = props.contactId;
  if (!aid || !cid) return;
  const candidates = [
    { name: 'contacts_show', params: { accountId: aid, contactId: cid }, query: route.query },
    { name: 'contacts_view', params: { accountId: aid, id: cid }, query: route.query },
  ];
  for (const c of candidates) { try { await router.push(c); return; } catch(_) {} }
  window.open(`/app/accounts/${aid}/contacts/${cid}`, '_blank');
};
const openChatWithContact = async () => {
  const aid = route.params?.accountId;
  const cid = props.contactId;
  if (!aid || !cid) return;
  const candidates = [
    { name: 'contacts_show', params: { accountId: aid, contactId: cid }, query: { ...route.query, open: 'chat' } },
    { name: 'conversations_list', params: { accountId: aid }, query: { ...route.query, contact_id: cid } },
  ];
  for (const c of candidates) { try { await router.push(c); return; } catch(_) {} }
  window.open(`/app/accounts/${aid}/contacts/${cid}#conversations`, '_blank');
};
const openWhatsApp = () => {
  const digits = (props.contactPhone || '').toString().replace(/\D+/g, '');
  if (!digits) return;
  window.open(`https://wa.me/${digits}?text=${encodeURIComponent('Olá! Podemos falar sobre seu atendimento?')}`, '_blank');
};
const openEmail = () => {
  const mail = (props.contactEmail || '').toString().trim();
  if (!mail) return;
  const subject = encodeURIComponent('Atendimento');
  const body = encodeURIComponent('Olá,\n\nPodemos dar continuidade por aqui?\n');
  window.location.href = `mailto:${mail}?subject=${subject}&body=${body}`;
};

/** ======= salvar ======= */
const handleUpdate = () => {
  const payload = {
    id: leadData.value.id,
    title: leadData.value.title,
    contact_name: leadData.value.contactName,
    contact_email: leadData.value.contactEmail,
    contact_phone: leadData.value.contactPhone,
    amount_cents: leadData.value.amountCents,
    deal_stage_id: leadData.value.dealStageId,
  };
  emit('update-lead', payload);
};
</script>

<template>
  <!-- CardLayout padrão Chatwoot -->
  <CardLayout :key="id" layout="row" class="!px-4 !py-3">
    <!-- ESQUERDA: avatar + infos -->
    <div class="flex items-center gap-3 flex-1 min-w-0">
      <Avatar :name="leadData.title || contactName" :src="thumbnail" :size="40" rounded-full />

      <div class="flex flex-col gap-1 flex-1 min-w-0">
        <!-- Linha principal: título (à esquerda) + valor / link (à direita em telas ≥ md) -->
        <div class="flex items-start gap-2 min-w-0">
          <div class="flex-1 min-w-0">
            <h3 class="text-[15px] font-medium leading-5 truncate text-n-slate-12">
              {{ leadData.title || '—' }}
            </h3>

            <!-- meta compacta: contato / email / telefone -->
            <div class="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-sm text-n-slate-11">
              <span class="truncate max-w-64" :title="leadData.contactName">{{ leadData.contactName || '—' }}</span>
              <span v-if="leadData.contactEmail" class="h-3 w-px bg-n-slate-6" />
              <span v-if="leadData.contactEmail" class="truncate max-w-48">{{ leadData.contactEmail }}</span>
              <span v-if="leadData.contactPhone" class="h-3 w-px bg-n-slate-6" />
              <span v-if="leadData.contactPhone" class="truncate max-w-40">{{ leadData.contactPhone }}</span>
            </div>

            <!-- badges pipeline/estágio -->
            <div class="mt-1 flex flex-wrap items-center gap-2">
              <span class="inline-flex items-center rounded-full bg-n-alpha-2 text-n-slate-11 px-2 py-0.5 text-[11px]">
                <Icon icon="i-lucide-git-branch" class="mr-1 h-3.5 w-3.5" /> {{ displayPipeline }}
              </span>
              <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px]" :class="stageClasses">
                <Icon icon="i-lucide-flag" class="mr-1 h-3.5 w-3.5" /> {{ displayStage }}
              </span>
            </div>

            <!-- ações compactas (ícones) -->
            <div class="mt-1.5 flex items-center gap-1.5">
              <Button
                v-if="contactId"
                size="xs" variant="ghost" color="slate"
                icon="i-lucide-user" title="Ver contato" aria-label="Ver contato"
                @click="openContactDetails"
              />
              <Button
                v-if="contactId"
                size="xs" variant="ghost" color="blue"
                icon="i-lucide-message-circle" title="Abrir chat" aria-label="Abrir chat"
                @click="openChatWithContact"
              />
              <Button
                v-if="contactPhone"
                size="xs" variant="ghost" color="teal"
                icon="i-lucide-phone" title="WhatsApp" aria-label="WhatsApp"
                @click="openWhatsApp"
              />
              <Button
                v-if="contactEmail"
                size="xs" variant="ghost" color="amber"
                icon="i-lucide-mail" title="E-mail" aria-label="E-mail"
                @click="openEmail"
              />
            </div>
          </div>

          <!-- DIREITA (md+): valor e "Ver detalhes" para aproveitar melhor o espaço -->
          <div class="hidden md:flex flex-col items-end gap-1 min-w-[180px] pl-2">
            <div class="text-sm font-medium text-n-slate-12">{{ formattedAmount }}</div>
            <Button
              :label="t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS') || 'Ver detalhes'"
              variant="link" size="xs"
              @click="onClickViewDetails"
            />
            <div class="text-[11px] text-n-slate-10">Atualizado: {{ formattedDate }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Chevron para expandir -->
    <Button
      icon="i-lucide-chevron-down"
      variant="ghost" color="slate" size="xs"
      class="self-start mt-1"
      :class="{ 'rotate-180': isExpanded }"
      title="Editar" aria-label="Editar"
      @click="onClickExpand"
    />

    <!-- Conteúdo expandível -->
    <template #after>
      <div class="transition-all duration-300 ease-in-out grid overflow-hidden"
           :class="isExpanded ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'">
        <div class="overflow-hidden">
          <div class="flex flex-col gap-4 p-4 border-t border-n-strong bg-n-0">
            <!-- Form com Input.vue (sm) -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <Input
                label="Título"
                v-model="leadData.title"
                type="text"
                placeholder="Ex.: Proposta ACME"
                :customInputClass="'!h-8 !text-sm'"
              />
              <Input
                label="Valor (centavos)"
                v-model.number="leadData.amountCents"
                type="number"
                placeholder="Ex.: 150000"
                :customInputClass="'!h-8 !text-sm'"
              />

              <Input
                label="Contato"
                v-model="leadData.contactName"
                type="text"
                placeholder="Nome do contato"
                :customInputClass="'!h-8 !text-sm'"
              />
              <Input
                label="E-mail"
                v-model="leadData.contactEmail"
                type="email"
                placeholder="nome@dominio.com"
                :customInputClass="'!h-8 !text-sm'"
              />

              <Input
                label="WhatsApp / Telefone"
                v-model="leadData.contactPhone"
                type="tel"
                placeholder="(11) 91234-5678"
                :customInputClass="'!h-8 !text-sm'"
              />
              <Input
                label="Última atualização"
                :modelValue="formattedDate"
                disabled
                :customInputClass="'!h-8 !text-sm bg-n-2'"
              />
            </div>

            <div class="flex justify-end gap-2">
              <Button label="Cancelar" variant="ghost" size="sm" @click="onClickExpand" />
              <Button
                :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON') || 'Salvar'"
                size="sm"
                :is-loading="isUpdating"
                @click="handleUpdate"
              />
            </div>
          </div>
        </div>
      </div>
    </template>
  </CardLayout>
</template>
