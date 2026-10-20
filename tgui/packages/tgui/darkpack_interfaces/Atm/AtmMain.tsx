import { useState } from 'react';
import { Box, Button, Input, LabeledList, Section } from 'tgui-core/components';

import { useBackend } from '../../backend';

import type { ATMData } from './types';

export const AtmMain = (props) => {
  const { act, data } = useBackend<ATMData>();
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [newPin, setNewPin] = useState('');

  const { account_holder, atm_balance, account_balance, inserted_cash } = data;

  const handleLogout = () => {
    act('logout');
  };

  const handleWithdraw = () => {
    act('withdraw', { withdraw_amount: withdrawAmount });
  };

  const handleDeposit = () => {
    act('deposit');
  };

  const handleChangePin = () => {
    act('change_pin', { new_pin: newPin });
    setNewPin('');
  };

  return (
    <Section>
      <LabeledList>
        <LabeledList.Item label="Account Owner">
          {account_holder}
        </LabeledList.Item>
        <LabeledList.Item label="Balance">{account_balance}</LabeledList.Item>
        <LabeledList.Item label="Money in ATM">{atm_balance}</LabeledList.Item>
        <LabeledList.Item label="Ready to deposit">
          {inserted_cash}
        </LabeledList.Item>
      </LabeledList>
      <Box mt={2}>
        <Box className="Atm__atm-column">
          <Box className="Atm__atm-row">
            <Button onClick={handleWithdraw} className="Atm__atm-button">
              Withdraw
            </Button>
            <Input
              value={withdrawAmount}
              onChange={setWithdrawAmount}
              placeholder="Withdraw Amount"
              style={{ flex: 3 }}
            />
          </Box>

          <Box className="Atm__atm-row">
            <Button
              disabled={!/^[0-9]{4}$/.test(newPin)}
              onClick={handleChangePin}
              className="Atm__atm-button"
            >
              Change Pin
            </Button>
            <input
              className="Input"
              type="password"
              inputMode="numeric"
              autoComplete="off"
              maxLength={4}
              value={newPin}
              onChange={(event) => setNewPin(event.currentTarget.value)}
              placeholder="New PIN"
              style={{ flex: 3 }}
            />
          </Box>

          <Box className="Atm__atm-row">
            <Button
              disabled={inserted_cash <= 0}
              onClick={handleDeposit}
              className="Atm__atm-button"
            >
              Deposit
            </Button>
          </Box>

          <Box className="Atm__atm-row">
            <Button onClick={handleLogout} className="Atm__atm-button">
              Log Out
            </Button>
          </Box>
        </Box>
      </Box>
    </Section>
  );
};
