# Taxi journeys

A Taxi Driver carrying another active player in an actual taxi can provide a
conversation bonus. Each driver/passenger pair must stay aboard continuously for
at least two minutes, finish at least ten tiles from the pickup on the same map
level, and each say two distinct, nonempty messages inside the taxi after that
passenger boards. Forced speech, emotes and radio-only messages do not count.
Changing driver or leaving early starts a new journey; NPCs cannot qualify.
Disconnecting, going AFK or losing consciousness discards that pair's pending
time and speech. When both players are active again aboard the taxi, a fresh
pickup, two-minute window and dialogue count begin.

On disembarking, the passenger receives **+1 die to the next three Storyteller
checks**, including combat checks, lasting at most **twenty minutes**. Cached or
cooldown-blocked rolls consume no charge. Only one taxi effect can exist; another
ride neither stacks nor refreshes its duration/charges. Other status effects
keep their normal rules. The native status alert uses the existing steering-wheel
icon, a Ratwood-style readable countdown (20m, then seconds), remaining charges
and a hover description. It uses Crimson's status system rather than a separate
HUD or a chat-only reminder.

Drivers receive **0.1 RCP per different passenger account**, capped at **0.5 RCP
per round** by default. Both numbers are configurable. The account ledger survives
reconnects and reloads; repeated delivery of the same passenger cannot farm RCP.
Taxi RCP is separate from the existing end-of-round participation grant. A valid
delivery still counts if its passenger already has the conversation effect.

This change uses existing taxis and jobs; it adds no dispatch UI, fare system,
automatic money payment, maps or new Karma rewards. It builds on the account
progression branch so RCP has the same persistent storage and Respect meaning.


Club Workers (including Stripper, Club Bartender and Club Attendant, but excluding
Club Bouncer) can also grant a **Memorable kiss** bonus. Eligibility uses the
alternate title assigned at spawn, not later preferences or ID cards. Both active players must remain within three visible tiles for at
least two minutes starting with their first accepted line, and each say two
distinct local lines. Leaving this radius or line of sight resets progress.
Pending pairs are also checked periodically, so disconnecting, fainting or a
closed door can invalidate idle progress.
Use the normal `*kiss` emote and aim its kiss at the guest: the ordinary harmless
kiss must actually hit the intended guest. Damaging and special kiss variants
cannot grant the bonus. No RCP is granted for kisses.

The kiss has its own native **heart icon**, countdown and three charges lasting
twenty minutes. It stacks with the taxi effect: a check receives +2 dice while
both are active and spends one charge of each. Another kiss never refills or
refreshes the same effect. Provider and guest must be different player accounts.
