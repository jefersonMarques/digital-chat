<template>
    <Dialog ref="dialog" width="md" :title="'Criar lead'"
        :description="'Preencha os dados do lead e selecione um contato pelo telefone. Se não encontrar, crie um novo contato.'"
        :isLoading="submitting" @close="onDialogClose">
        <div class="flex flex-col gap-6">
            <!-- ========== LEAD ========== -->
            <div class="flex flex-col gap-2">
                <h4 class="text-sm font-medium text-n-slate-12">Lead</h4>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <Input label="Título *" v-model.trim="lead.title" type="text" placeholder="Ex.: Proposta ACME"
                        :customInputClass="'!h-8 !text-sm'" />

                    <Input label="Valor" v-model="lead.amount" type="text" placeholder="1.234,56"
                        :customInputClass="'!h-8 !text-sm'" />

                    <div class="flex flex-col gap-1">
                        <label class="text-sm font-medium text-n-slate-12 mb-1">Pipeline *</label>
                        <ComboBox v-model="lead.pipelineId" :options="pipelinesOptions"
                            placeholder="Selecione um pipeline" class="w-full" @select="onPipelineSelect" />
                    </div>

                    <div class="flex flex-col gap-1">
                        <label class="text-sm font-medium text-n-slate-12 mb-1">Status *</label>
                        <ComboBox v-model="lead.status" :options="statusOptions" placeholder="Selecione o status"
                            class="w-full" />
                    </div>
                </div>
            </div>

            <!-- ========== CONTATO ========== -->
            <div class="flex flex-col gap-2">
                <h4 class="text-sm font-medium text-n-slate-12">Contato</h4>

                <!-- telefone + botão novo contato -->
                <div class="grid grid-cols-[1fr_auto] gap-2 items-start">
                    <div class="relative" @keydown="onSuggestKeydown('phone', $event)">
                        <PhoneNumberInput v-model="contact.phoneRaw" :label="'Telefone *'"
                            :placeholder="'(11) 91234-5678'" :message="phoneHelperMessage"
                            :message-type="phoneHelperType" @update:modelValue="onPhoneUpdate" @focus="onPhoneFocus"
                            @blur="onPhoneBlur" :customInputClass="'!h-8 !text-sm'" />
                        <!-- sugestões -->
                        <div v-if="phoneSuggest.open && phoneSuggest.list.length"
                            class="absolute z-50 w-full mt-1 border rounded-xl shadow-xl bg-white dark:bg-n-solid-1 border-n-strong"
                            role="listbox">
                            <div v-for="(c, i) in phoneSuggest.list" :key="'p-' + String(c.id || i)"
                                class="px-3 py-2 cursor-pointer text-sm hover:bg-n-alpha-2"
                                :class="{ 'bg-n-alpha-2': i === phoneSuggest.hi }" role="option"
                                @mousedown.prevent="selectSuggestion(c)">
                                <div class="font-semibold text-[13px] text-n-slate-12">{{ c.name || 'Sem nome' }}</div>
                                <div class="text-[12px] text-n-slate-11">
                                    <span v-if="c.phone_number">{{ c.phone_number }}</span>
                                    <span v-if="c.email"> · {{ c.email }}</span>
                                    <span v-if="!c.phone_number && !c.email" class="text-n-slate-9">Sem
                                        telefone/e-mail</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <Button :label="newContact.isOpen ? 'Fechar' : 'Novo contato'" variant="outline" color="slate"
                        size="sm" class="self-end" @click="toggleNewContact" />
                </div>

                <!-- contato selecionado -->
                <div v-if="contact.selected" class="flex items-center gap-3 text-sm text-n-slate-11">
                    <span class="inline-flex items-center rounded-full bg-n-alpha-2 px-2 py-1">
                        <span class="font-medium text-n-slate-12">{{ contact.selected.name || 'Sem nome' }}</span>
                        <span v-if="contact.selected.email" class="mx-2 h-3 w-px bg-n-slate-6" />
                        <span v-if="contact.selected.email">{{ contact.selected.email }}</span>
                        <span v-if="contact.selected.phone_number" class="mx-2 h-3 w-px bg-n-slate-6" />
                        <span v-if="contact.selected.phone_number">{{ contact.selected.phone_number }}</span>
                    </span>
                    <Button label="Trocar" variant="link" size="xs" @click="clearSelectedContact" />
                </div>

                <!-- subform novo contato -->
                <div v-if="newContact.isOpen" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <Input label="Primeiro nome *" v-model.trim="newContact.firstName" type="text" placeholder="João"
                        :customInputClass="'!h-8 !text-sm'" />
                    <Input label="Sobrenome" v-model.trim="newContact.lastName" type="text" placeholder="Silva"
                        :customInputClass="'!h-8 !text-sm'" />
                    <Input label="E-mail" v-model.trim="newContact.email" type="email" placeholder="joao@empresa.com"
                        :message="newEmailError" :message-type="newEmailError ? 'error' : 'info'" @blur="onNewEmailBlur"
                        :customInputClass="'!h-8 !text-sm'" />
                    <Input label="Empresa" v-model.trim="newContact.company" type="text" placeholder="ACME Ltda"
                        :customInputClass="'!h-8 !text-sm'" />
                </div>
            </div>
        </div>

        <!-- Rodapé -->
        <template #footer>
            <div class="flex items-center justify-end gap-3 mt-4">
                <Button type="button" label="Cancelar" variant="outline" color="slate" size="sm" @click="close" />
                <Button type="button" label="Criar" variant="solid" size="sm" :disabled="!canSubmit || submitting"
                    :is-loading="submitting" @click="submit" />
            </div>
        </template>
    </Dialog>
</template>

<script>
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

function http() {
    const ax = typeof window !== 'undefined' ? window.axios : null;
    if (!ax) throw new Error('HTTP do Chatwoot indisponível');
    return ax;
}

export default {
    name: 'NewLeadDialog',
    components: { Dialog, Input, PhoneNumberInput, ComboBox, Button },
    props: { accountId: { type: [String, Number], required: false } },
    data() {
        return {
            // contexto
            accountIdResolved: null,
            pipelines: [],

            // UI
            isOpen: false,
            submitting: false,

            // lead
            lead: {
                title: '',
                amount: '',
                pipelineId: '',
                status: 'open',
                stageIdAuto: '', // <= novo: estágio default do pipeline
            },

            // contato
            contact: { phoneRaw: '', selected: null },
            phoneSuggest: { open: false, list: [], hi: -1, last: '' },

            // subform de novo contato
            newContact: { isOpen: false, firstName: '', lastName: '', email: '', company: '' },
            newEmailError: '',

            // debounce
            d: { phone: null },
        };
    },
    computed: {
        pipelinesOptions() {
            return (this.pipelines || []).map(p => ({ value: String(p.id), label: p.name || String(p.id) }));
        },
        statusOptions() {
            return [
                { value: 'open', label: 'Aberto' },
                { value: 'won', label: 'Ganho' },
                { value: 'lost', label: 'Perdido' },
                { value: 'archived', label: 'Arquivado' },
            ];
        },

        // validações
        isValidPhone() {
            const e164 = this.normalizePhone(this.contact.phoneRaw);
            return !!e164 && /^\+\d{11,15}$/.test(e164);
        },
        newContactValid() {
            return this.isValidPhone && !!this.newContact.firstName?.trim() && !this.newEmailError;
        },
        hasContact() {
            return !!(this.contact.selected && this.contact.selected.id) || (this.newContact.isOpen && this.newContactValid);
        },
        canSubmit() {
            return (
                !!this.lead.title?.trim() &&
                !!this.lead.pipelineId &&
                !!this.lead.status &&
                this.hasContact
            );
        },

        phoneHelperMessage() {
            if (!this.isValidPhone && this.contact.phoneRaw) return 'Informe um telefone válido com DDI (ex.: +55...)';
            if (!this.hasContact) return 'Selecione um contato nas sugestões ou clique em "Novo contato".';
            return '';
        },
        phoneHelperType() {
            if (!this.isValidPhone && this.contact.phoneRaw) return 'error';
            return 'info';
        },
    },
    methods: {
        /** ===================== contexto ===================== */
        async resolveContext() {
            const fromRoute = this.$route?.params?.accountId;
            const fromProp = this.accountId;
            const fromStore = this.$store?.getters?.getCurrentUser?.account_id;
            this.accountIdResolved = String(fromRoute || fromProp || fromStore || '').trim();
            if (!this.accountIdResolved) throw new Error('Não foi possível resolver o accountId.');
        },

        async loadPipelines() {
            const { data } = await http().get(`/api/v1/accounts/${this.accountIdResolved}/deal_pipelines`);
            this.pipelines = Array.isArray(data) ? data : [];
            if (!this.lead.pipelineId && this.pipelines.length) {
                this.lead.pipelineId = String(this.pipelines[0].id);
            }
            await this.loadDefaultStageForPipeline(this.lead.pipelineId);
        },

        async loadDefaultStageForPipeline(pipelineId) {
            this.lead.stageIdAuto = '';
            if (!pipelineId) return;
            try {
                const { data } = await http().get(
                    `/api/v1/accounts/${this.accountIdResolved}/deal_pipelines/${pipelineId}/deal_stages`
                );
                const arr = Array.isArray(data) ? data : [];
                let first = arr[0];
                if (arr.length && typeof arr[0]?.position === 'number') {
                    first = [...arr].sort((a, b) => (a.position || 0) - (b.position || 0))[0];
                }
                this.lead.stageIdAuto = first ? String(first.id) : '';
            } catch (_) {
                this.lead.stageIdAuto = '';
            }
        },

        /** ===================== UI ===================== */
        onPipelineSelect(opt) {
            this.lead.pipelineId = String(opt?.value || '');
            this.loadDefaultStageForPipeline(this.lead.pipelineId).catch(() => { });
        },
        toggleNewContact() {
            this.newContact.isOpen = !this.newContact.isOpen;
            if (this.newContact.isOpen) {
                this.contact.selected = null;
            } else {
                this.newContact.firstName = '';
                this.newContact.lastName = '';
                this.newContact.email = '';
                this.newContact.company = '';
                this.newEmailError = '';
            }
        },
        clearSelectedContact() { this.contact.selected = null; },

        /** ===================== helpers de telefone ===================== */
        toDigits(s) {
            return (s || '').toString().replace(/\D+/g, '');
        },
        phonesEqual(a, b) {
            const da = this.toDigits(a);
            const db = this.toDigits(b);
            if (!da || !db) return false;
            if (da === db) return true;
            const a10 = da.slice(-10), b10 = db.slice(-10);
            const a11 = da.slice(-11), b11 = db.slice(-11);
            return a10 === b10 || a11 === b11;
        },

        /** ===================== buscas / sugestões ===================== */
        async searchContacts(q) {
            if (!q || !q.trim()) return [];
            const { data } = await http().get(
                `/api/v1/accounts/${this.accountIdResolved}/contacts/search`,
                { params: { q } }
            );
            const list = Array.isArray(data?.payload) ? data.payload : (Array.isArray(data) ? data : []);
            return list.map(c => ({
                id: c.id ?? c.source_id ?? c.contact_id ?? null,
                name: c.name ?? c.contact_name ?? '',
                phone_number: c.phone_number ?? c.phone ?? '',
                email: c.email ?? c.email_id ?? '',
            }));
        },

        async findContactByPhone(e164) {
            try {
                const { data } = await http().get(
                    `/api/v1/accounts/${this.accountIdResolved}/contacts`,
                    { params: { phone_number: e164, page: 1 } }
                );
                const arr = Array.isArray(data?.data) ? data.data : (Array.isArray(data) ? data : []);
                return (arr && arr.length) ? arr[0] : null;
            } catch { return null; }
        },

        async findContactByEmail(email) {
            if (!email) return null;
            const { data } = await http().get(
                `/api/v1/accounts/${this.accountIdResolved}/contacts/search`,
                { params: { q: email } }
            );
            const list = Array.isArray(data?.payload) ? data.payload : (Array.isArray(data) ? data : []);
            const lower = email.toLowerCase();
            return list.find(c => (c.email || c.email_id || '').toLowerCase?.() === lower) || null;
        },

        // Busca robusta: tenta por endpoint dedicado, depois /search e faz match por telefone/e-mail
        async findContactSmart({ e164 = '', digits = '', email = '' } = {}) {
            if (e164) {
                const byPhone = await this.findContactByPhone(e164);
                if (byPhone?.id) return byPhone;
            }
            const q = e164 || digits || email || '';
            if (!q) return null;

            const { data } = await http().get(
                `/api/v1/accounts/${this.accountIdResolved}/contacts/search`,
                { params: { q } }
            );
            const list = Array.isArray(data?.payload) ? data.payload : (Array.isArray(data) ? data : []);
            const emailLower = (email || '').toLowerCase();

            const found = list.find(c => {
                const phone = c.phone_number || c.phone || '';
                const mail = (c.email || c.email_id || '').toLowerCase?.();
                return (e164 && this.phonesEqual(phone, e164)) ||
                    (digits && this.phonesEqual(phone, digits)) ||
                    (email && mail && mail === emailLower);
            });
            return found || null;
        },

        /** ===================== telefone / sugestões (UI) ===================== */
        onPhoneUpdate(val) {
            let s = '';
            if (val && typeof val === 'object') {
                s = val.e164 || val.value || [
                    val.countryCode ? `+${val.countryCode}` : '',
                    val.nationalNumber || val.number || '',
                ].join('');
            } else {
                s = String(val || '');
            }
            this.contact.phoneRaw = s;

            clearTimeout(this.d.phone);
            this.d.phone = setTimeout(async () => {
                const raw = String(this.contact.phoneRaw || '').trim();
                const digits = this.toDigits(raw);
                if (digits.length >= 3) this.triggerPhoneSuggest(raw); else this.closeSuggest();

                const e164 = this.normalizePhone(raw);
                const found = await this.findContactSmart({ e164, digits });
                if (found?.id) {
                    this.contact.selected = {
                        id: found.id,
                        name: found.name || found.contact_name || '',
                        email: found.email || found.email_id || '',
                        phone_number: found.phone_number || found.phone || '',
                    };
                    this.newContact.isOpen = false;
                }
            }, 250);
        },

        onPhoneFocus() {
            const raw = String(this.contact.phoneRaw || '').trim();
            const digits = this.toDigits(raw);
            if (digits.length >= 3) this.triggerPhoneSuggest(raw);
        },
        onPhoneBlur() { setTimeout(this.closeSuggest, 120); },

        async triggerPhoneSuggest(raw) {
            const q = raw.trim();
            this.phoneSuggest.last = q;
            const results = await this.searchContacts(q);
            if (this.phoneSuggest.last !== q) return;
            this.phoneSuggest.list = results.slice(0, 8);
            this.phoneSuggest.open = this.phoneSuggest.list.length > 0;
            this.phoneSuggest.hi = this.phoneSuggest.open ? 0 : -1;
        },

        closeSuggest() { this.phoneSuggest.open = false; this.phoneSuggest.list = []; this.phoneSuggest.hi = -1; },

        selectSuggestion(c) {
            this.contact.selected = {
                id: c.id,
                name: c.name || '',
                email: c.email || '',
                phone_number: c.phone_number || '',
            };
            this.newContact.isOpen = false;
            this.closeSuggest();
        },

        onSuggestKeydown(_, e) {
            const box = this.phoneSuggest;
            if (!box.open) return;
            if (e.key === 'ArrowDown') { e.preventDefault(); box.hi = Math.min(box.hi + 1, box.list.length - 1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); box.hi = Math.max(box.hi - 1, 0); }
            else if (e.key === 'Enter') {
                if (box.hi >= 0 && box.list[box.hi]) { e.preventDefault(); this.selectSuggestion(box.list[box.hi]); }
            } else if (e.key === 'Escape') { e.preventDefault(); this.closeSuggest(); }
        },

        /** ===================== novo contato: email ===================== */
        onNewEmailBlur() {
            const email = (this.newContact.email || '').trim();
            if (!email) { this.newEmailError = ''; return; }
            const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
            this.newEmailError = ok ? '' : 'E-mail inválido.';
        },

        /** ===================== open/close ===================== */
        async open() {
            try {
                if (!this.accountIdResolved) await this.resolveContext();
                await this.loadPipelines();

                this.submitting = false;
                this.lead = {
                    title: '',
                    amount: '',
                    pipelineId: this.lead.pipelineId || (this.pipelines[0]?.id ? String(this.pipelines[0].id) : ''),
                    status: 'open',
                    stageIdAuto: this.lead.stageIdAuto || '',
                };
                if (!this.lead.stageIdAuto) await this.loadDefaultStageForPipeline(this.lead.pipelineId);

                this.contact = { phoneRaw: '', selected: null };
                this.newContact = { isOpen: false, firstName: '', lastName: '', email: '', company: '' };
                this.newEmailError = '';
                this.phoneSuggest = { open: false, list: [], hi: -1, last: '' };

                this.isOpen = true;
                this.$refs.dialog?.open?.();
            } catch (e) { console.error(e); }
        },

        close() {
            if (this.submitting) return;
            this.isOpen = false;
            this.$refs.dialog?.close?.();
        },

        onDialogClose() {
            if (this.submitting) return;
            this.isOpen = false;
        },

        /** ===================== garante contact_id ===================== */
        async ensureContactId() {
            // 0) já selecionado
            if (this.contact.selected?.id) return Number(this.contact.selected.id);

            const e164 = this.normalizePhone(this.contact.phoneRaw);
            const digits = this.toDigits(this.contact.phoneRaw);
            const email = (this.newContact.email || '').trim();

            // 1) tenta achar existente por telefone/email (sem clicar na sugestão)
            const existing = await this.findContactSmart({ e164, digits, email });
            if (existing?.id) return Number(existing.id);

            // 2) criar novo contato (se subform estiver aberto e válido)
            if (this.newContact.isOpen && this.newContactValid) {
                if (email) {
                    const byEmail = await this.findContactByEmail(email);
                    if (byEmail?.id) return Number(byEmail.id);
                }

                const payload = {
                    name: [this.newContact.firstName, this.newContact.lastName].filter(Boolean).join(' ').trim() || e164,
                    phone_number: e164,
                };
                if (email) payload.email = email;
                if (this.newContact.company) payload.additional_attributes = { company: this.newContact.company.trim() };

                try {
                    const created = await this.createContact(payload);
                    const cid =
                        created?.id ??
                        created?.contact?.id ??
                        created?.source_id ??
                        created?.contact_id ??
                        created?.data?.id ??
                        created?.payload?.id ?? null;
                    if (cid) return Number(cid);
                } catch (e) {
                    if (e?.response?.status === 422) {
                        const again = await this.findContactSmart({ e164, digits, email });
                        if (again?.id) return Number(again.id);
                    }
                    throw e;
                }
            }

            // 3) falha
            throw new Error('Selecione um contato existente ou crie um novo.');
        },

        /** ===================== submit ===================== */
        async submit() {
            if (!this.canSubmit) return;
            this.submitting = true;
            try {
                const contactId = await this.ensureContactId();

                const amount_cents = this.parseBRCurrencyToCents(this.lead.amount);
                const payloadDeal = {
                    title: this.lead.title.trim(),
                    deal_pipeline_id: Number(this.lead.pipelineId),
                    status: this.lead.status,
                    contact_id: Number(contactId),
                    ...(amount_cents != null ? { amount_cents } : {}),
                    ...(this.lead.stageIdAuto ? { deal_stage_id: Number(this.lead.stageIdAuto) } : {}),
                };

                const deal = await this.createDeal(payloadDeal);
                this.close();
                this.$emit('created', deal);
            } catch (e) {
                console.error('Falha ao criar lead:', e?.response?.data || e);
            } finally {
                this.submitting = false;
            }
        },

        /** ===================== HTTP helpers ===================== */
        async createDeal(payload) {
            // controller exige params.require(:deal)
            const { data } = await http().post(
                `/api/v1/accounts/${this.accountIdResolved}/deals`,
                { deal: payload }
            );
            return data;
        },

        async createContact(payload) {
            const { data } = await http().post(
                `/api/v1/accounts/${this.accountIdResolved}/contacts`,
                payload
            );
            return data;
        },

        /** ===================== utils ===================== */
        normalizePhone(input) {
            if (!input) return '';
            let s = String(input).trim().replace(/[\s()-]/g, '');
            s = s.startsWith('+') ? '+' + s.replace(/[^\d]/g, '') : '+' + s.replace(/[^\d]/g, '');
            return s;
        },

        parseBRCurrencyToCents(str) {
            if (!str) return null;
            let v = String(str).trim().replace(/[^\d.,-]/g, '');
            if (v.includes(',')) v = v.replace(/\./g, '').replace(',', '.');
            const n = Number(v);
            if (Number.isNaN(n)) return null;
            return Math.round(n * 100);
        },
    },
};
</script>
