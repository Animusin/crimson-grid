import type { BooleanLike } from 'tgui-core/react';

export type ATMData = {
  logged_in: BooleanLike;
  card: BooleanLike;
  inserted_cash: number;
  atm_balance: number | null;

  // Account details are sent only to the authenticated session's user.
  account_balance: number | null;
  account_holder: string | null;
  account_id: number | null;
};
