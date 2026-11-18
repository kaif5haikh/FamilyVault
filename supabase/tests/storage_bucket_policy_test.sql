BEGIN;
SET LOCAL plpgsql.check_asserts=on;
INSERT INTO storage.objects VALUES ('familyvault-ciphertext','synthetic-sealed-version');
DO $$
BEGIN
  BEGIN
    UPDATE storage.buckets SET public=true WHERE id='familyvault-ciphertext';
    RAISE EXCEPTION 'FamilyVault bucket was made public';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  SET LOCAL ROLE authenticated;
  ASSERT NOT EXISTS (SELECT 1 FROM storage.objects);
  BEGIN
    INSERT INTO storage.objects VALUES ('familyvault-ciphertext','unauthorized-object');
    RAISE EXCEPTION 'An unrelated permissive policy opened direct object writes';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
ROLLBACK;
