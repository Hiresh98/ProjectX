import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  Link as RouterLink,
  useNavigate,
  useSearchParams,
} from 'react-router-dom';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Link from '@mui/material/Link';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { resetPasswordSchema, type ResetPasswordValues } from './auth.schemas';
import { useResetPasswordMutation } from '@/services/authApi';
import { getApiErrorMessage } from '@/utils/getApiErrorMessage';

export function ResetPasswordPage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token') ?? '';
  const navigate = useNavigate();
  const [reset, { isLoading, error }] = useResetPasswordMutation();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ResetPasswordValues>({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: { password: '', confirmPassword: '' },
  });

  const onSubmit = handleSubmit(async (values) => {
    await reset({ token, password: values.password }).unwrap();
    navigate('/login', { replace: true });
  });

  if (!token) {
    return (
      <Stack spacing={2}>
        <Alert severity="error">Missing or invalid reset token.</Alert>
        <Link component={RouterLink} to="/forgot-password" variant="body2">
          Request a new link
        </Link>
      </Stack>
    );
  }

  return (
    <Box component="form" onSubmit={(e) => void onSubmit(e)} noValidate>
      <Typography variant="h6" gutterBottom>
        Choose a new password
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {getApiErrorMessage(error)}
        </Alert>
      )}

      <Stack spacing={2}>
        <TextField
          label="New password"
          type="password"
          autoComplete="new-password"
          fullWidth
          error={Boolean(errors.password)}
          helperText={errors.password?.message}
          {...register('password')}
        />
        <TextField
          label="Confirm password"
          type="password"
          autoComplete="new-password"
          fullWidth
          error={Boolean(errors.confirmPassword)}
          helperText={errors.confirmPassword?.message}
          {...register('confirmPassword')}
        />
        <Button type="submit" variant="contained" disabled={isLoading}>
          {isLoading ? 'Saving…' : 'Reset password'}
        </Button>
      </Stack>
    </Box>
  );
}

export default ResetPasswordPage;
