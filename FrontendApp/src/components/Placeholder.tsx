import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import { PageHeader } from './PageHeader';

interface PlaceholderProps {
  title: string;
}

/**
 * Stand-in for feature modules not yet implemented. Each maps to a real,
 * permission-guarded route so navigation/RBAC can be exercised end-to-end;
 * the CRUD UI is delivered per-module in later phases.
 */
export function Placeholder({ title }: PlaceholderProps) {
  return (
    <Box>
      <PageHeader title={title} />
      <Alert severity="info">
        The <strong>{title}</strong> module is scaffolded and routed. CRUD UI +
        RTK Query endpoints land in the next phase.
      </Alert>
    </Box>
  );
}
