import { useState } from 'react';
import { Button, LabeledList, Section } from 'tgui-core/components';
import { useBackend } from '../../backend';

import type { ATMData } from './types';

export const AtmLogin = (props) => {
  const { act, data } = useBackend<ATMData>();
  const [enteredCode, setEnteredCode] = useState('');

  const handleLogin = () => {
    act('login', { bank_pin: enteredCode });
    setEnteredCode('');
  };
  return (
    <Section
      title={data.card ? 'Enter your four-digit PIN' : 'Swipe your debit card'}
    >
      <LabeledList>
        <LabeledList.Item label="PIN">
          <input
            className="Input"
            type="password"
            inputMode="numeric"
            autoComplete="off"
            maxLength={4}
            disabled={!data.card}
            value={enteredCode}
            placeholder="Four-digit PIN"
            onChange={(event) => setEnteredCode(event.currentTarget.value)}
          />
        </LabeledList.Item>
        <LabeledList.Item>
          <Button
            disabled={!data.card || !/^[0-9]{4}$/.test(enteredCode)}
            onClick={handleLogin}
          >
            Log In
          </Button>
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};
