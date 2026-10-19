import { useBackend } from 'tgui/backend';
import { Box, Button, Section, Stack } from 'tgui-core/components';
import type { PreferencesMenuData } from '../types';

function ageAccess(cap: number) {
  return cap < 0
    ? 'Kindred unavailable'
    : `Kindred age up to ${cap} years since Embrace`;
}

export function CharacterProgression() {
  const { act, data } = useBackend<PreferencesMenuData>();
  const progression = data.character_progression;
  if (!progression) return null;

  const ticket = progression.unlock_ticket;
  return (
    <Section title="Character record">
      <Box color="label" mb={0.5}>
        Cosmetics are free. Learned Paths and taught discipline choices persist.
      </Box>
      {!progression.locked ? (
        <Box>
          Settings remain free until this character first joins a round.
        </Box>
      ) : (
        <>
          <Box mb={0.5}>
            {ticket
              ? `${ticket === 'full' ? 'All settings' : 'Stats and abilities'} unlocked until your next spawn.`
              : 'This character is saved. Unlock settings to edit a future round’s sheet.'}
          </Box>
          {!progression.can_unlock && (
            <Box color="label" mb={0.5}>
              Return to the lobby to unlock settings.
            </Box>
          )}
          <Stack>
            {!ticket && (
              <Stack.Item grow>
                <Button
                  icon="unlock"
                  disabled={!progression.can_unlock || progression.karma < 3}
                  onClick={() =>
                    act('quality_unlock_character', { scope: 'stats' })
                  }
                >
                  Stats and abilities: 3 Karma
                </Button>
                <Box color="label" mt={0.5}>
                  After spending: Respect {progression.stats_respect};{' '}
                  {ageAccess(progression.stats_age_cap)}.
                </Box>
              </Stack.Item>
            )}
            {ticket !== 'full' && (
              <Stack.Item grow>
                <Button
                  icon="unlock"
                  disabled={
                    !progression.can_unlock ||
                    progression.karma < progression.full_cost
                  }
                  onClick={() =>
                    act('quality_unlock_character', { scope: 'full' })
                  }
                >
                  {ticket === 'stats'
                    ? 'Upgrade to all settings'
                    : 'All settings'}
                  : {progression.full_cost} Karma
                </Button>
                <Box color="label" mt={0.5}>
                  After spending: Respect {progression.full_respect};{' '}
                  {ageAccess(progression.full_age_cap)}.
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </>
      )}
    </Section>
  );
}
