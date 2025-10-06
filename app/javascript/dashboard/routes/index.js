import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import AnalyticsHelper from '../helper/AnalyticsHelper';
import salesChildRoutes from './sales/sales.routes';


const routes = [...dashboard.routes];

// acha a rota-pai que renderiza o shell/Sidebar
const accountsRoot = routes.find(r => r.path === '/app/accounts/:accountId');
if (accountsRoot?.children) {
  accountsRoot.children.push(...salesChildRoutes);
} else {
  // fallback (não deve acontecer, mas evita quebrar)
  routes.push(
    ...salesChildRoutes.map(r => ({
      ...r,
      path: `/app/accounts/:accountId/${r.path}`,
    }))
  );
}

export const router = createRouter({ history: createWebHistory(), routes });

export const validateAuthenticateRoutePermission = (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  if (!to.name) {
    return next(frontendURL(`accounts/${user.account_id}/dashboard`));
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach((to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    userAuthentication.then(() => {
      return validateAuthenticateRoutePermission(to, next, store);
    });
  });
};

export default router;
