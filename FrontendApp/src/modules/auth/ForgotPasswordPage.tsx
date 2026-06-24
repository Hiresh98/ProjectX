import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Link as RouterLink } from 'react-router-dom';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Link from '@mui/material/Link';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import {
  forgotPasswordSchema,
  type ForgotPasswordValues,
} from './auth.schemas';
import { useForgotPasswordMutation } from '@/services/authApi';

export function ForgotPasswordPage() {
  const [forgot, { isLoading, isSuccess, data }] = useForgotPasswordMutation();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ForgotPasswordValues>({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: '' },
  });

  const onSubmit = handleSubmit(async (values) => {
    await forgot(values).unwrap();
  });

  return (
    <Box component="form" onSubmit={(e) => void onSubmit(e)} noValidate>
      <Typography variant="h6" gutterBottom>
        Reset your password
      </Typography>

      {isSuccess ? (
        <Stack spacing={2}>
          <Alert severity="success">
            If an account exists for that email, a reset link has been sent.
          </Alert>
          {/* Dev convenience: backend returns a reset URL in non-prod. */}
          {data?.devResetUrl && (
            <Alert severity="info">
              Dev link: <Link href={data.devResetUrl}>{data.devResetUrl}</Link>
            </Alert>
          )}
          <Link component={RouterLink} to="/login" variant="body2">
            Back to sign in
          </Link>
        </Stack>
      ) : (
        <Stack spacing={2}>
          <TextField
            label="Email"
            type="email"
            autoComplete="email"
            fullWidth
            error={Boolean(errors.email)}
            helperText={errors.email?.message}
            {...register('email')}
          />
          <Button type="submit" variant="contained" disabled={isLoading}>
            {isLoading ? 'Sending…' : 'Send reset link'}
          </Button>
          <Link component={RouterLink} to="/login" variant="body2">
            Back to sign in
          </Link>
        </Stack>
      )}
    </Box>
  );
}

export default ForgotPasswordPage;
