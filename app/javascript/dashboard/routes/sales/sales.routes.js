// app/javascript/dashboard/routes/sales/sales.routes.js
import SalesViewSwitcher from 'dashboard/components/sales/SalesViewSwitcher.vue';
import { ROLES } from 'dashboard/constants/permissions.js';

export default [
  {
    path: 'sales/kanban',
    name: 'sales_kanban',
    component: SalesViewSwitcher, // ← trocado
    props: true,
    meta: { requiresAuth: true, permissions: [...ROLES] },
  },
];
