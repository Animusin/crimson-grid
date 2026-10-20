import type { FeatureChoiced } from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const slim_body_build: FeatureChoiced = {
  name: 'Body build',
  description: 'Slim sprites are currently available for female human bodies.',
  component: FeatureDropdownInput,
};
